require File.dirname(__FILE__) + '/../../spec_helper'

describe YARD::Templates::Helpers::HtmlHelper do
  include YARD::Templates::Helpers::HtmlHelper

  describe '#h' do
    it "should use #h to escape HTML" do
      h('Usage: foo "bar" <baz>').should == "Usage: foo &quot;bar&quot; &lt;baz&gt;"
    end
  end
  
  describe '#fix_typewriter' do
    it "should use #fix_typewriter to convert +text+ to <tt>text</tt>" do
      fix_typewriter("Some +typewriter text+.").should == 
        "Some <tt>t\x04y\x04p\x04e\x04w\x04r\x04i\x04t\x04e\x04r\x04" +
        " \x04t\x04e\x04x\x04t\x04</tt>."
      fix_typewriter("Not +typewriter text.").should == 
        "Not +typewriter text."
      fix_typewriter("Alternating +type writer+ text +here+.").should == 
        "Alternating <tt>t\x04y\x04p\x04e\x04 \x04w\x04r\x04i\x04t\x04e\x04r" +
        "\x04</tt> text <tt>h\x04e\x04r\x04e\x04</tt>."
      fix_typewriter("No ++problem.").should == 
        "No ++problem."
      fix_typewriter("Math + stuff +is ok+").should == 
        "Math + stuff <tt>i\x04s\x04 \x04o\x04k\x04</tt>"
    end
  end
  
  describe '#format_types' do
    it "should include brackets by default" do
      text = ["String"]
      should_receive(:linkify).at_least(1).times.with("String", "String").and_return("String")
      format_types(text).should == format_types(text, true)
      format_types(text).should == "(<tt>String</tt>)"
    end

    it "should avoid brackets if brackets=false" do
      should_receive(:linkify).with("String", "String").and_return("String")
      should_receive(:linkify).with("Symbol", "Symbol").and_return("Symbol")
      format_types(["String", "Symbol"], false).should == "<tt>String</tt>, <tt>Symbol</tt>"
    end
    
    { "String" => [["String"], 
        "<tt><a href=''>String</a></tt>"], 
      "A::B::C" => [["A::B::C"], 
        "<tt><a href=''>A::B::C</a></tt>"],
      "Array<String>" => [["Array", "String"], 
        "<tt><a href=''>Array</a>&lt;<a href=''>String</a>&gt;</tt>"], 
      "Array<String, Symbol>" => [["Array", "String", "Symbol"], 
        "<tt><a href=''>Array</a>&lt;<a href=''>String</a>, <a href=''>Symbol</a>&gt;</tt>"],
      "Array<{String => Array<Symbol>}>" => [["Array", "String", "Array", "Symbol"], 
        "<tt><a href=''>Array</a>&lt;{<a href=''>String</a> =&gt; " +
        "<a href=''>Array</a>&lt;<a href=''>Symbol</a>&gt;}&gt;</tt>"]
    }.each do |text, values|
      it "should link all classes in #{text}" do
        should_receive(:h).with('<').at_least(text.count('<')).times.and_return("&lt;")
        should_receive(:h).with('>').at_least(text.count('>')).times.and_return("&gt;")
        values[0].each {|v| should_receive(:linkify).with(v, v).and_return("<a href=''>#{v}</a>") }
        format_types([text], false).should == values[1]
      end
    end
  end
  
  describe '#htmlify' do
    it "should not use hard breaks for textile markup (RedCloth specific)" do
      htmlify("A\nB", :textile).should_not include("<br")
    end
  end

  describe "#link_object" do
    it "should return the object path if there's no serializer and no title" do
      stub!(:serializer).and_return nil
      link_object(CodeObjects::NamespaceObject.new(nil, :YARD)).should == "YARD"
    end
  
    it "should return the title if there's a title but no serializer" do
      stub!(:serializer).and_return nil
      link_object(CodeObjects::NamespaceObject.new(nil, :YARD), 'title').should == "title"
    end
  end

  describe '#url_for' do
    before { Registry.clear }
  
    it "should return nil if serializer is nil" do
      stub!(:serializer).and_return nil
      stub!(:object).and_return Registry.root
      url_for(P("Mod::Class#meth")).should be_nil
    end
  
    it "should return nil if serializer does not implement #serialized_path" do
      stub!(:serializer).and_return Serializers::Base.new
      stub!(:object).and_return Registry.root
      url_for(P("Mod::Class#meth")).should be_nil
    end
  
    it "should link to a path/file for a namespace object" do
      stub!(:serializer).and_return Serializers::FileSystemSerializer.new
      stub!(:object).and_return Registry.root
    
      yard = CodeObjects::ModuleObject.new(:root, :YARD)
      url_for(yard).should == 'YARD.html'
    end
  
    it "should link to the object's namespace path/file and use the object as the anchor" do
      stub!(:serializer).and_return Serializers::FileSystemSerializer.new
      stub!(:object).and_return Registry.root
    
      yard = CodeObjects::ModuleObject.new(:root, :YARD)
      meth = CodeObjects::MethodObject.new(yard, :meth)
      url_for(meth).should == 'YARD.html#meth-instance_method'
    end

    it "should properly urlencode methods with punctuation in links" do
      obj = CodeObjects::MethodObject.new(nil, :/)
      serializer = mock(:serializer)
      serializer.stub!(:serialized_path).and_return("file.html")
      stub!(:serializer).and_return(serializer)
      stub!(:object).and_return(obj)
      url_for(obj).should == "#%2F-instance_method"
    end
  end

  describe '#anchor_for' do
    it "should not urlencode data when called directly" do
      obj = CodeObjects::MethodObject.new(nil, :/)
      anchor_for(obj).should == "/-instance_method"
    end
  end

  describe '#resolve_links' do
    def parse_link(link)
      results = {}
      link =~ /<a (.+?)>(.+?)<\/a>/
      params, results[:inner_text] = $1, $2
      params.split(/\s+/).each do |match|
        key, value = *match.split('=')
        results[key.to_sym] = value.gsub(/^["'](.+)["']$/, '\1')
      end
      results
    end

    it "should link static files with file: prefix" do
      stub!(:serializer).and_return Serializers::FileSystemSerializer.new
      stub!(:object).and_return Registry.root

      parse_link(resolve_links("{file:TEST.txt#abc}")).should == {
        :inner_text => "TEST.txt",
        :title => "TEST.txt",
        :href => "file.TEST.html#abc"
      }
      parse_link(resolve_links("{file:TEST.txt title}")).should == {
        :inner_text => "title",
        :title => "title",
        :href => "file.TEST.html"
      }
    end
  
    it "should create regular links with http:// or https:// prefixes" do
      parse_link(resolve_links("{http://example.com}")).should == {
        :inner_text => "http://example.com",
        :target => "_parent",
        :href => "http://example.com",
        :title => "http://example.com"
      }
      parse_link(resolve_links("{http://example.com title}")).should == {
        :inner_text => "title",
        :target => "_parent",
        :href => "http://example.com",
        :title => "title"
      }
    end
    
    it "should create mailto links with mailto: prefixes" do
      parse_link(resolve_links('{mailto:joanna@example.com}')).should == {
        :inner_text => 'mailto:joanna@example.com',
        :target => '_parent',
        :href => 'mailto:joanna@example.com',
        :title => 'mailto:joanna@example.com'
      }
      parse_link(resolve_links('{mailto:steve@example.com Steve}')).should == {
        :inner_text => 'Steve',
        :target => '_parent',
        :href => 'mailto:steve@example.com',
        :title => 'Steve'
      }
    end
  end
end