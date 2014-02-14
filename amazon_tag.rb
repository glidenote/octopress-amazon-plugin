require 'amazon/ecs'
require 'pp'

module Jekyll
  class AmazonResultCache
    def initialize
      @result_cache = {}

      @cache = false
      @cache_dir = ".amazon-cache/"
      @options = {
        :associate_tag     => nil,
        :AWS_access_key_id => nil,
        :AWS_secret_key    => nil,
        :response_group    => 'Images,ItemAttributes,ItemIds',
        :country           => 'en',
      }
    end

    @@instance = AmazonResultCache.new

    def self.instance
      @@instance
    end

    def setup(context)
      site = context.registers[:site]

      #cache_dir
      @cache = site.config['amazon_cache'] if site.config['amazon_cache']
      @cache_dir = site.config['amazon_cache_dir'].gsub(/\/$/, '') + '/' if site.config['amazon_cache_dir']
      Dir::mkdir(@cache_dir) if File.exists?(@cache_dir) == false

      #options
      @options[:associate_tag]     = site.config['amazon_associate_tag']
      @options[:AWS_access_key_id] = site.config['amazon_access_key_id']
      @options[:AWS_secret_key]    = site.config['amazon_secret_key']
      @options[:country]           = site.config['amazon_country']
    end

    def item_lookup(asin)
      return @result_cache[asin] if @result_cache.has_key?(asin)
      return @result_cache[asin] = Marshal.load(File.read(@cache_dir + asin)) if @cache && File.exist?(@cache_dir + asin)

      Amazon::Ecs.options = @options

      recnt = 0
      begin
        res = Amazon::Ecs.item_lookup(asin)

      #Liquid Exception HTTP Response: 503 Service Unavailable
      rescue Amazon::RequestError => e
        if /503/ =~ e.message && recnt < 3
          sleep 3
          recnt += 1
          puts asin + " retry " + recnt.to_s
          retry
        else
          raise e
        end
      end

      res.items.each do |item|
        data = {
          :title => item.get('ItemAttributes/Title').to_s.gsub(/ \[Blu-ray\]/, '').gsub(/ \(Ultimate Edition\)/, ''),
          :item_page_url => item.get('DetailPageURL').to_s,
          :small_image_url => item.get('SmallImage/URL').to_s,
          :medium_image_url => item.get('MediumImage/URL').to_s,
          :large_image_url => item.get('LargeImage/URL').to_s,
        }
        @result_cache[asin] = data
        open(@cache_dir + asin, "w"){|f| f.write(Marshal.dump(data))} if @cache
        break
      end
      return @result_cache[asin]
    end

    private_class_method :new
  end

  class AmazonTag < Liquid::Tag

    def initialize(name, params, token)
      super
      @params = params
    end

    def render(context)
      if @params =~ /(?<type>(text|small_image.*|medium_image.*|large_image.*).*\s+)(?<asin>\S+)/i
        type = $~['type'].strip
        asin = $~['asin'].strip.gsub(/"|&ldquo;|&rdquo;/, '')
      else
        raise "parametor error for amazon tag"
      end

      AmazonResultCache.instance.setup(context)
      item = AmazonResultCache.instance.item_lookup(asin)

      if item.nil?
        raise "item data empty asin %s" % [asin]
      end

      self.send(type, item)
    end

    def text(item)
      url = item[:item_page_url]
      title = item[:title]
      '<a href="%s">%s</a>' % [url, title]
    end

    def small_image(item)
      url = item[:item_page_url]
      image_url = item[:small_image_url]
      '<a href="%s"><img src="%s" /></a>' % [url, image_url]
    end

    def small_image_left(item)
      url = item[:item_page_url]
      image_url = item[:small_image_url]
      '<a href="%s"><img src="%s" align="left" /></a>' % [url, image_url]
    end

    def small_image_right(item)
      url = item[:item_page_url]
      image_url = item[:small_image_url]
      '<a href="%s"><img src="%s" align="right" /></a>' % [url, image_url]
    end

    def medium_image(item)
      url = item[:item_page_url]
      image_url = item[:medium_image_url]
      '<a href="%s"><img src="%s" /></a>' % [url, image_url]
    end

    def medium_image_left(item)
      url = item[:item_page_url]
      image_url = item[:medium_image_url]
      '<a href="%s"><img src="%s" align="left" /></a>' % [url, image_url]
    end

    def medium_image_right(item)
      url = item[:item_page_url]
      image_url = item[:medium_image_url]
      '<a href="%s"><img src="%s" align="right" /></a>' % [url, image_url]
    end

    def large_image(item)
      url = item[:item_page_url]
      image_url = item[:large_image_url]
      '<a href="%s"><img src="%s" /></a>' % [url, image_url]
    end

    def large_image_left(item)
      url = item[:item_page_url]
      image_url = item[:large_image_url]
      '<a href="%s"><img src="%s" align="left" /></a>' % [url, image_url]
    end

    def large_image_right(item)
      url = item[:item_page_url]
      image_url = item[:large_image_url]
      '<a href="%s"><img src="%s" align="right" /></a>' % [url, image_url]
    end

  end

end
Liquid::Template.register_tag('amazon', Jekyll::AmazonTag)
