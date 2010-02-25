
require 'rubygems'
require 'rjb'
require 'sinatra'
require 'json'
require 'phrase_tree'

# Initialize JVM
raise "Need JAVA_HOME environment variable (without a trailing slash)." unless ENV['JAVA_HOME']
classpaths = ['.']
Dir::open(File.join(File.dirname(__FILE__), '/dependencies')).entries.each do |entry|
  if entry =~ /\.jar$/
    puts "Java VM, loading: #{entry}"
    classpaths << File.join(File.dirname(__FILE__), "/dependencies/#{entry}")
  end
end

ENV['LD_LIBRARY_PATH'] = "#{ENV['LD_LIBRARY_PATH']}:#{ENV['JAVA_HOME']}/jre/lib/i386:#{ENV['JAVA_HOME']}/jre/lib/i386/client:/usr/local/lib"
Rjb::load(classpath = classpaths.join(':'), jvmargs=['-Xms64m', '-Xmx128m', '-Djava.library.path=/usr/lib:/usr/local/lib', '-Dwordnet.configfile=data/wordnet/file_properties.xml', '-Drelex.algpath=data/relex-semantic-algs.txt'])

class Relex < Sinatra::Base
  
  System            = Rjb::import('java.lang.System')
  OpenCogScheme     = Rjb::import('relex.output.OpenCogScheme')
  SimpleView        = Rjb::import('relex.output.SimpleView')
  Frame             = Rjb::import('relex.frame.Frame')
  ParsedSentence    = Rjb::import('relex.ParsedSentence')
  RelationExtractor = Rjb::import('relex.RelationExtractor')
  ChunkRanker       = Rjb::import('relex.chunk.ChunkRanker')
  PhraseChunker     = Rjb::import('relex.chunk.PhraseChunker')
  PatternChunker    = Rjb::import('relex.chunk.PatternChunker')
  RelationChunker   = Rjb::import('relex.chunk.RelationChunker')
  
  CHUNKER_MAX_PARSES = 4
  CHUNKER_MAX_PARSE_SECONDS = 2
  FRAME_EXTRACT_RE = /^\^(\d)_(\w+):(\w+)\((\w+),(\w+)\)/
     
  def initialize
    @relation_extractor = RelationExtractor.new(false)
    @open_cog_scheme = OpenCogScheme.new
    @frameset = Frame.new
  end
  
  def phrase_tree(parsed_sentence)
    str = parsed_sentence.getPhraseString
    str = str.slice(0, str.size-1)
    tree = PhraseTree.new(str).to_a
    {
      :string => str,
      :tree_array => tree,
      :flat_array => tree.flatten
    }
  end
  
  def frames(parsed_sentence)
     relations = SimpleView.printRelationsAlt(parsed_sentence)
     relex_frames = @frameset.process(relations)
     frames = {}
     relex_frames.each do |relex_frame|
       match = relex_frame.match(FRAME_EXTRACT_RE)
       frame_group = frames[match[2]]
       frame_group ||= []
       frame_group << {match[3] => [match[4], match[5]]}
       frames[match[2]] = frame_group
     end
     frames
   end
   
   [:get, :post].each do |method|
     
     send(method.to_s, '/') do
       content_type(:json)
       parsed_sentence = parse(params[:text])
       json_with_callback({
         :frames => frames(parsed_sentence),
         :phrase_tree => phrase_tree(parsed_sentence)
       }, params[:callback])
     end
     
     send(method.to_s, '/frame') do
       content_type(:json)
       json_with_callback(frames(parse(params[:text])), params[:callback])
     end
     
     send(method.to_s, '/phrase_tree') do
       content_type(:json)
       json_with_callback(phrase_tree(parsed_sentence = parse(params[:text])), params[:callback])
     end
   end 
   
   
   private
   
   def parse(sentence)
     relex_info = @relation_extractor.processSentence(sentence)
     relex_info.getParses.get(0)
   end
   
   def json_with_callback(data, callback)
     callback ? "#{callback}(#{data.to_json});" : data.to_json
   end
   
end

Relex.run!(:host => 'localhost', :port => 9090)
