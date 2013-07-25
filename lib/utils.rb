# encoding: UTF-8

##
# This module contains a collection of helpers for Upton
##
module Upton

  ##
  # This class contains a collection of helpers for Upton
  #
  # Each method returns a Proc that (with an & ) can be used as the final
  # argument to Upton's `scrape` and `scrape_to_csv`
  ##
  module Utils

    ##
    # Scrapes an HTML <table> element into an Array of Arrays. The header, if
    # present, is returned as the first row.
    ##
    def self.table(table_selector, selector_method=:xpath)
      require 'csv'
      return Proc.new do |instance_html|
        html = ::Nokogiri::HTML(instance_html)
        output = []
        headers = html.send(selector_method, table_selector).css("th").map &:text
        output << headers

        table = html.send(selector_method, table_selector).css("tr").each{|tr| output << tr.css("td").map(&:text) }
        output
      end
    end

    ##
    # Scrapes any set of HTML elements into an Array. 
    ##
    def self.list(list_selector, selector_method=:xpath)
      require 'csv'
      return Proc.new do |instance_html|
        html = ::Nokogiri::HTML(instance_html)
        html.send(selector_method, list_selector).map{|list_element| list_element.text }
      end
    end

    class Index

      def initialize(url, selector="", selector_method=:xpath)
        @index_url = index_url_or_array
        @index_selector = selector
        @index_selector_method = selector_method
      end

      ##
      # Return a list of URLs for the instances you want to scrape.
      # This can optionally be overridden if, for example, the list of instances
      # comes from an API.
      ##
      def get_index
        parse_index(get_index_pages(@index_url, 1), @index_selector, @index_selector_method)
      end

      ##
      # Using the XPath expression or CSS selector and selector_method that 
      # uniquely identifies the links in the index, return those links as strings.
      ##
      def parse_index(text, selector, selector_method=:xpath)
        Nokogiri::HTML(text).send(selector_method, selector).to_a.map{|l| l["href"] }
      end

      ##
      # Returns the concatenated output of each member of a paginated index,
      # e.g. a site listing links with 2+ pages.
      ##
      def get_index_pages(url, index)
        resp = self.get_page(url, @index_debug)
        if !resp.empty? 
          next_url = self.next_index_page_url(url, index + 1)
          unless next_url == url
            next_resp = self.get_index_pages(next_url, index + 1).to_s 
            resp += next_resp
          end
        end
        resp
      end

    end

  end
end
