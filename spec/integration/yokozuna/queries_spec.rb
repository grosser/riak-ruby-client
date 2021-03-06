# encoding: UTF-8
require 'spec_helper'
require 'riak'

describe "Yokozuna queries", test_client: true, integration: true do
  before :all do
    @client = test_client
  end

  context "with a schema and indexes" do
    before :all do
      @bucket = random_bucket 'yz-spec'
      @index = @bucket.name

      expect(@client.create_search_index(@index)).to eq(true)
      wait_until{ !@client.get_search_index(@index).nil? }
      @client.set_bucket_props(@bucket, {:search_index => @index}, 'yokozuna')

      wait_until do
        props = @client.get_bucket_props(@bucket, type: 'yokozuna')
        props['search_index'] == @index
      end

      @o1 = build_json_obj(@bucket, "cat", {"cat_s"=>"Lela"})
      @o2 = build_json_obj(@bucket, "docs", {"dog_ss"=>%w(Einstein Olive)})
      build_json_obj(@bucket, "Z", {"username_s"=>"Z", "name_s"=>"ryan", "age_i"=>30})
      build_json_obj(@bucket, "R", {"username_s"=>"R", "name_s"=>"eric", "age_i"=>34})
      build_json_obj(@bucket, "F", {"username_s"=>"F", "name_s"=>"bryan fink", "age_i"=>32})
      build_json_obj(@bucket, "H", {"username_s"=>"H", "name_s"=>"brett", "age_i"=>14})

      wait_until { @client.search(@index, "username_s:Z")['docs'].length > 0 }
    end

    it "produces results on single term queries" do
      resp = @client.search(@index, "username_s:Z")
      expect(resp).to include('docs')
      expect(resp['docs'].size).to eq(1)
    end

    it "produces results on multiple term queries" do
      resp = @client.search(@index, "username_s:(F OR H)")
      expect(resp).to include('docs')
      expect(resp['docs'].size).to eq(2)
    end

    it "produces results on queries with boolean logic" do
      resp = @client.search(@index, "username_s:Z AND name_s:ryan")
      expect(resp).to include('docs')
      expect(resp['docs'].size).to eq(1)
    end

    it "produces results on range queries" do
      resp = @client.search(@index, "age_i:[30 TO 33]")
      expect(resp).to include('docs')
      expect(resp['docs'].size).to eq(2)
    end

    it "produces results on phrase queries" do
      resp = @client.search(@index, 'name_s:"bryan fink"')
      expect(resp).to include('docs')
      expect(resp['docs'].size).to eq(1)
    end

    it "produces results on wildcard queries" do
      resp = @client.search(@index, "name_s:*ryan*")
      expect(resp).to include('docs')
      expect(resp['docs'].size).to eq(2)
    end

    it "produces results on regexp queries" do
      resp = @client.search(@index, "name_s:/br.*/")
      expect(resp).to include('docs')
      expect(resp['docs'].size).to eq(2)
    end

    it "supports utf8" do
      build_json_obj(@bucket, "ja", {"text_ja"=>"私はハイビスカスを食べるのが 大好き"})
      sleep 2.1  # pause for index commit to trigger
      resp = @client.search(@index, "text_ja:大好き")
      expect(resp).to include('docs')
      expect(resp['docs'].size).to eq 1
    end

    context "using parameters" do
      it "searches one row" do
        resp = @client.search(@index, "*:*", {:rows => 1})
        expect(resp).to include('docs')
        expect(resp['docs'].size).to eq(1)
      end

      it "searches with df" do
        resp = @client.search(@index, "Olive", {:rows => 1, :df => 'dog_ss'})
        expect(resp).to include('docs')
        expect(resp['docs'].size).to eq(1)
        resp['docs'].first['dog_ss']
      end

      it "produces top result on sort" do
        resp = @client.search(@index, "username_s:*", {:sort => "age_i asc"})
        expect(resp).to include('docs')
        expect(resp['docs'].first['age_i'].to_i).to eq(14)
      end

    end
  end

  # populate objects
  def build_json_obj(bucket, key, data)
    object = bucket.get_or_new(key)
    object.raw_data = data.to_json
    object.content_type = 'application/json'
    object.store type: 'yokozuna'
    object
  end
end
