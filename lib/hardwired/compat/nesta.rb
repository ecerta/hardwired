
#NestaCMS compatibility shims

#For Nesta .mdown compatibility - Still need to rename *.erubis -> *.erb
Tilt.register 'mdown', Tilt[:md] 

module Nesta
  Page = Hardwired::Page
  module Path
    def self.local(*args)
      Hardwired::Paths.root_path(File.join(args))
    end
  end
end

module Hardwired
	class Page

		def metadata(name)
			meta[name]
		end

    def description
      meta.description
    end

    def date(format = nil)
      format == :xmlschema && super ? super().xmlschema : super()
    end

     def keywords
      meta.keywords
    end

    def flagged_as? (flag)
    	flag? flag
    end

    def lib(name)
    	lib?(name)
    end

    def abspath
      path
    end
    
    def categories
    	[]
    end

    def self.find_by_path(path)
      Hardwired::Index[path]
    end

    def self.find_all
      Index.pages
    end

    def self.find_articles
      Index.posts
    end
    
    def top_articles(count = 10)
      Page.find_articles.select { |a| a.date }[0..count-1]
    end
  
    def articles_by_tags
       Hardwired::Page.find_articles.select { |article| not (article.tags & self.tags).empty? }
     end
     def self.articles_by_tag(tag)
       Hardwired::Page.find_articles.select { |article| not (article.tags & [tag]).empty? }
     end

  end
end

module Hardwired
  module Nesta
    extend SinatraExtension

   	## Make Nesta::Config work
    before '*' do
    	Nesta::Config = Hardwired::Config.config unless defined?(Nesta::Config)
    end



    helpers do

			def before_render_file(file)
				#@config = config

				@page = file
				@title = file.title if file.is_page?
				@description = file.meta.description
				@keywords = file.meta.keywords
        @google_analytics_code = config.google_analytics_code
			end


    
      def base_url
        request.base_url
      end
  
      def absolute_urls(text)
        text.gsub!(/(<a href=['"])\//, '\1' + base_url + '/') if text 
        text
      end
  
      def nesta_atom_id_for_page(page)
        published = page.date.strftime('%Y-%m-%d')
        "tag:#{request.host},#{published}:#{page.path}"
      end
  
      def atom_id(page = nil)
        if page
          page.atom_id || nesta_atom_id_for_page(page)
        else
          "tag:#{request.host},2009:/"
        end
      end
  
      def format_date(date)
        date.strftime("%d %B %Y")
      end
 

      def local_stylesheet_link_tag(name)
        pattern = File.expand_path(Hardwired::Paths.content_path("/css/#{name}.s{a,c}?ss"))
        if Dir.glob(pattern).size > 0
          haml_tag :link, :href => "/css/#{name}.css", :rel => "stylesheet"
        end
      end


    	def breadcrumb_ancestors
        ancestors = []
        page = @page
        while page
          ancestors << page
          page = page.parent
        end
        ancestors.reverse
      end

      def display_breadcrumbs(options = {})
        haml_tag :ul, :class => options[:class] do
          breadcrumb_ancestors[0...-1].each do |page|
            haml_tag :li do
              haml_tag :a, :<, :href => path_to(page.path), :itemprop => 'url' do
                haml_tag :span, :<, :itemprop => 'title' do
                  haml_concat link_text(page)
                end
              end
            end
          end
          haml_tag(:li, :class => current_breadcrumb_class) do
            haml_concat link_text(@page)
          end
        end
      end
     end

  end
end

