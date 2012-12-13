# Migrating from Wordpress to Hardwired

An import script and set of routes to help migrate content and attachments from Wordpress with minimal hassle.

The import script follows redirects, builds a set of compatibility paths for each page, and downloads attachments. It expects everything to be on the same domain, and cross-domain redirects will confuse it. 


## Migration guide

### Part 1. Preparing for the conversion

1. Make sure you have a new or existing Hardwired site, with all new and modified files committed to Git.  We'll call this 'your site' from now on. And we're assuming all commands specified here are executed from the root of your site. We're also expecting all files in UTF-8 form.
2. Edit your gemfile to include the following additional gems:

        gem "hpricot", :group => :development
        gem "rake", :group => :development

3. Run `bundle install`
4. Make sure your Wordpress site is still running and available at its original location. It needs to be online for the redirect tracker and attachment downloader to work.
5. Go to Tools-> Export on your Wordpress site. Choose "All content", and save the exported file as "wordpress.xml" in the root of your new site.
6. In your Disqus account, make a site matching your current domain. Make sure the Website URL matches the primary website URL of your site. 
7. In Disqus, go to Tools>Import and import the wordpress.xml file. Wait till it's finished.
8. In Disqus, go to Tools>Migrate Threads> Redirect Crawler. Start the redirect crawler; this should consolidate all your comments and associate them with the 'primary' version of each article. **Remember**: You'll need to do this a second time after you've pointed the domain to the new Hardwired server.

## Part 2. The Theory of conversion

### Content conversion rules

* Page and Post content will be converted from HTML to XHTML. The conversion is done with Hpricot followed by Nokogiri. Hpricot has the best element closure detection, Nokogiri enforces proper entity encoding. This mimics browser 'autocorrection' very well, and shouldn't corrupt your content. 
* The title is placed at the beginning of the content between &lt;h1>&lt;/h1> tags. 

### Wordpress metadata conversion rules

* Metadata pairs with null or empty values are discarded.
* Metadata pairs with keys starting in "\_" are discarded. (With the exception of \_wp\_page\_template, which becomes wp\_template in the page header)
* User-defined fields are added to the end of the file as XML comments.
* Author IDs are converted to Author Display Names
* If available, the GMT post date is used for the Date: field instead of the time-zone specific value. The Date: field is omitted for 'Page' items.
* Password-protected pages/posts will be given `wp_status: protected` and `Flags: draft`, but the password will not be copied.
* The following data is dropped: Sticky post flags, comment status, menu order, post parents, and ping status values.
* wp_categories and wp_tags are merged (with dupe removal) to create the Tags array.

### Generated metadata example

      Aliases: /image-resizer-installation/ /?page_id=91 /?p=91
      Atom ID: http://66.29.219.39/?page_id=91
      Post ID: 91
      Author: Nathanael Jones
      Summary: This is the article summary
      Flags: draft
      Tags: image-resizing, installation, image-resizer
      wp_date: 2010-11-11 19:44:48 -0500
      wp_template: default
      wp_status: private
      wp_categories: image-resizing, installation
      wp_tags: image-resizing, image-resizer

### Post naming rules

* Public 'Posts' will be placed in /content/blog/YYYY/post-title-sanitized.htmf
* Non-public 'Posts' will be placed in /content/drafts/post-title-sanitized.htmf and hidden with `Flags: draft`

### Page naming rules

* All 'Pages' with an assigned URL will be placed in a matching directory strucutre. I.e. /contact/donate will become /contact/donate.htmf
* If a Page doesn't have an assigned URL, it will be dumped in /drafts/
* If a Page is hidden, protected, etc, it will be hidden with `Flags: draft`
* index.htmf files are not generated for parent pages. Instead, you'll get 'name.htmf' and folder 'name' in the same directory.

### Attachment downloading rules

* Attachments will go into /attachments/wp-content/... They will keep the same directory structure and file name, except for `/attachments/` being prepended.
* Attachments will have a modified date matching their original Upload datestamp. 
* Attachments will be downloaded from the live site, following any redirections issued by the current server.

### Alias (301 redirect) generation rules

Aliases for each post and page are generated by taking the following URLs, requesting them, then collecting a list of all URLs they are redirected through. 

Wordpress does not always store the 'pretty url' in the database, but generates it dynamically. Often, the only way to get the 'official' url for a page is to execute the HTTP request.

* Wordpress Link (official URL for page or psot)
* Wordpress Guid (GUID Permalink)
* Wordpress Post ID (in the form /?p=[post id])
* Wordpress metadata "url" (user-defined "url" field)

The resulting set is made domain-relative and cleansed of duplicates. 

This is how the `Aliases: /?p=27 /1204_My_Article /2009/11/12/my-article` metadata tag is determined. 

## Part 3. Executing the script

Double-check you have everything committed before starting, so you can see what has been changed. Files can get overwritten.

#### This does a fast 'offline import'. Use this first to verify there are no errors

`bundle exec hw-import-wordpress -f -a`

#### Use this to perform a full import. Downloads all attachments and checks for 301/302 redirects to determine what aliases need to be specified for each page

`bundle exec hw-import-wordpress`

#### If you want to restore the "Author", "wp\_date", "wp\_template", and "wp\_status" metadata fields
  
`bundle exec hw-import-wordpress -d none`

#### If you, for some reason, want to delete all the metadata during conversion, run
  
`bundle exec hw-import-wordpress -d "Author","wp_status","Flags","wp_date","wp_template","Aliases","Atom ID","Post ID","Status","wp_categories","wp_tags","Tags","Summary","Date"`


#### If your XML files isn't named wordpress.xml, you can specify it
  
`bundle exec hw-import-wordpress -c wordpress-other-file.xml`

Once the conversion script has finished, make sure you review the log for errors. 

## Part 4. Post-conversion steps

1. Add the following routes to site.rb to prevent URL breakage:

        before '/wp-content/*' do
          request.path_info = "/attachments" + request.path_info
        end

        get '/feed/' do
           redirect '/rss.xml', 301
        end
        
        get '/comments/feed/' do
          if config.disqus_short_name
            redirect "#{config.disqus_short_name}.disqus.com/latest.rss", 301
          end
        end


2. Make sure disqus\_short\_name is set in config.yml

3. Create your layouts (specifically, 'page' is required)
4. Create (or copy) rss.xml.slim and sitemap.xml.slim
5. Create (or copy) your 404 and 500 error pages.
6. Replace each `wp_template: [name]` metadata pair with `Layout: [new-name]`, if that page needs a non-default layout. You can even monkey-patch to do a dynamic conversion from wp_template if you don't want to search & replace.

### The URLs with no easy solution


We didn't make landing pages for tags and categories! You can do this manually if you wish.

You'll probably see:

* 404s for /tag/{tag}/
* 404s for /category/{category}/
* 404s for /category/{category}/{child-category}/
* 404s for /{id}/{article}/feed/

Redirecting comment RSS feeds for individual pages seems nearly impossible. Disqus seems to use the normalized title of the page, which seems...fragile. Ex. http://shortname.disqus.com/normalized-title/latest.rss



### IntenseDebate vs. Disqus

As a long-time user of IntenseDebate, I originally wanted to port my IntenseDebate comments over directly. However, after using Disqus for a bit, I realized it was a much nicer service. And it imports directly from both IntenseDebate and Wordpress. 

If you want to stay with IntenseDebate, you'll have to do some coding for it

1. Edit your layouts to use IntenseDebate and set `idcomments_post_id` to the page.metadata.post_id value.

      <script>
      var idcomments_acct = ‘YOUR ACCT ID’;
      var idcomments_post_id; //<- this is where you use "Post ID"
      var idcomments_post_url;
      </script>
      <script type=”text/javascript” src=”http://www.intensedebate.com/js/genericLinkWrapperV2.js”></script>

2. Write code against the IntenseDebate API to fix your comment feed URLs

* /comments/feed/ to http://intensedebate.com/allBlogCommentsRSS/37301  (ID of blog with intensedebate)
* /id/article/feed/ to http://intensedebate.com/postRSS/104986059  (ID of post with intensedebate)


## Part 5. Post-publish steps

After you've:

* got your new Hardwired site working
* have switched the DNS so it's handling all requests for your site
* you've verified (by checking google webmaster logs) that you don't have any lingering 404s

THEN, re-run the Disqus redirect crawler so it will move your existing comments to your new URLs by following your 301 redirects. 

