# encoding: UTF-8

require 'nokogiri'
require 'uri'
require 'restclient'
require_relative './utils'

##
# This module contains a scraper called Upton
##
module Upton
  ##
  # *Upton* is a framework for easy web-scraping with a useful debug mode 
  # that doesn't hammer your target's servers. It does the repetitive parts of 
  # writing scrapers, so you only have to write the unique parts for each site.
  #
  # Upton operates on the theory that, for most scraping projects, you need to
  # scrape two types of pages:
  # 
  # 1. Index pages, which list instance pages. For example, a job search 
  #     site's search page or a newspaper's homepage.
  # 2. Instance pages, which represent the goal of your scraping, e.g.
  #     job listings or news articles.
  #
  # Upton::Scraper can be used as-is for basic use-cases by:
  # 1. specifying the pages to be scraped in `new` as an index page 
  #      or as an Array of URLs.
  # 2.  supplying a block to `scrape` or `scrape_to_csv` or using a pre-build 
  #      block from Upton::Utils.
  # For more complicated cases; subclass Upton::Scraper 
  #    e.g. +MyScraper < Upton::Scraper+ and overrdie various methods.
  ##
  class Scraper

    attr_accessor :verbose, :debug, :sleep_time_between_requests, :stash_folder, :url_array

    def scrape &blk
      self.scrape_from_list(self.url_array, blk)
    end

    def initialize(*urls)
      @url_array = urls

      @verbose = false
      @debug = true
      @index_debug = false
      @sleep_time_between_requests = 30 #seconds

      @stash_folder = "stashes"
      unless Dir.exists?(@stash_folder)
        Dir.mkdir(@stash_folder)
      end

    end

    def scrape_to_csv filename, &blk
      require 'csv'
      CSV.open filename, 'wb' do |csv|
        self.scrape_from_list(self.url_array, blk).each{|document| csv << document }
      end
    end

    protected

    ##
    # Handles getting pages with RestClient or getting them from the local stash.
    #
    # Uses a kludge (because rest-client is outdated) to handle encoding.
    ##
    def get_page(url, stash=false)
      return "" if url.empty?
      url = url.get_index if url.respond_to?(:get_index)

      #the filename for each stashed version is a cleaned version of the URL.
      if stash && File.exists?( File.join(@stash_folder, url.gsub(/[^A-Za-z0-9\-]/, "") ) )
        puts "usin' a stashed copy of " + url if @verbose
        resp = open( File.join(@stash_folder, url.gsub(/[^A-Za-z0-9\-]/, "")), 'r:UTF-8').read .encode("UTF-8", :invalid => :replace, :undef => :replace )
      else
        begin
          puts "getting " + url if @verbose
          sleep @sleep_time_between_requests
          resp = RestClient.get(url, {:accept=> "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"})

          #this is silly, but rest-client needs to get on their game.
          #cf https://github.com/jcoyne/rest-client/blob/fb80f2c320687943bc4fae1503ed15f9dff4ce64/lib/restclient/response.rb#L26
          if ((200..207).include?(resp.net_http_res.code.to_i) && content_type = resp.net_http_res.content_type)
            charset = if set = resp.net_http_res.type_params['charset'] 
              set
            elsif content_type == 'text/xml'
              'us-ascii'
            elsif content_type.split('/').first == 'text'
              'iso-8859-1'
            end
            resp.force_encoding(charset) if charset
          end

        rescue RestClient::ResourceNotFound
          puts "404 error, skipping: #{url}" if @verbose
          resp = ""
        rescue RestClient::InternalServerError
          puts "500 Error, skipping: #{url}" if @verbose
          resp = ""
        rescue URI::InvalidURIError
          puts "Invalid URI: #{url}" if @verbose
          resp = ""
        end
        if stash
          puts "I just stashed (#{resp.code if resp.respond_to?(:code)}): #{url}" if @verbose
          open( File.join(@stash_folder, url.gsub(/[^A-Za-z0-9\-]/, "") ), 'w:UTF-8'){|f| f.write(resp.encode("UTF-8", :invalid => :replace, :undef => :replace ) )}
        end
      end
      resp
    end

    ##
    # Returns the article at `url`.
    # 
    # If the page is stashed, returns that, otherwise, fetches it from the web.
    #
    # If an instance is paginated, returns the concatenated output of each 
    # page, e.g. if a news article has two pages.
    ##
    def get_instance(url, index=0)
      resp = self.get_page(url, @debug)
      if !resp.empty? 
        next_url = self.next_instance_page_url(url, index + 1)
        unless next_url == url
          next_resp = self.get_instance(next_url, index + 1).to_s 
          resp += next_resp
        end
      end
      resp
    end

    # Just a helper for +scrape+.
    def scrape_from_list(list, blk)
      puts "Scraping #{list.size} instances" if @verbose
      list.each_with_index.map do |instance_url, index|
        blk.call(get_instance(instance_url), instance_url, index)
      end
    end

    # it's often useful to have this slug method for uniquely (almost certainly) identifying pages.
    def slug(url)
      url.split("/")[-1].gsub(/\?.*/, "").gsub(/.html.*/, "")
    end

    def next_instance_page_url(url, index)
      ""
    end

    def next_index_page_url(url, index)
      ""
    end

  end
end
