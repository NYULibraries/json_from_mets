  require 'rubygems'
  require 'saxerator'
  require 'mongo'

  include Mongo


  def generate_single_pages()
    single_pages=[]
    map=@parser.for_tag(:div).with_attributes({:TYPE => "INTELLECTUAL_ENTITY"}).first
    map['div'].each.with_index do |page, index|
      label=page.attributes["ID"].gsub('s-', '')
      order=page.attributes["ORDER"].to_i
      page= { :isPartOf => @book_id, :sequence => [order], :realPageNumber => order,
              :cm => {:uri => "fileserver://books/#{@book_id}/#{label}_d.jp2", :width=>"", :height=>"", :levels=>"",
                      :dwtLevels=>"", :compositingLayerCount=>"", :timestamp => Time.now().to_i.to_s}}
      single_pages<<page
    end
    return single_pages
  end

  def generate_double_pages(number_of_pages)
    double_pages=[]
    i=0
    while (i < number_of_pages) do
      is_cover_or_back= (i==0||i==number_of_pages-1) ? :true : false

      left_img_num = i + 1
      right_img_num =i
      if (is_cover_or_back)
        right_img_num = (i + 1)
        i+=1
      else
        right_img_num = i + 2
        i += 2
      end
      stitch_index = "#{left_img_num}-#{right_img_num}"

      left_page_num = left_img_num
      right_page_num = right_img_num

      stitch_file ="#{@book_id}_2up_#{left_img_num.to_s.rjust(4,'0')}_#{right_img_num.to_s.rjust(4,'0')}"

      page= { :isPartOf => @book_id, :sequence => [left_img_num, right_img_num], :realPageNumber => [left_img_num, right_img_num],
              :cm => {:uri => "fileserver://books/#{@book_id}/#{stitch_file}.jp2",  :width=>"", :height=>"", :levels=>"",
                      :dwtLevels=>"", :compositingLayerCount=>"", :timestamp => Time.now().to_i.to_s}}
      double_pages<<page
    end
    return double_pages
  end

  @book_id=ARGV.first
  mongodb="mongodb://127.0.0.1:27017/#{ARGV[2]}"
  collection_path=ARGV[1]
  single_pages_collection=ARGV[3]||"dlts_books_page"
  double_pages_collection=ARGV[4]||"dlts_stitched_books_page"



  if ARGV.empty?||ARGV.empty?
    puts "You need to provide book id e.g. cornell_aco000001, name of your mongo db and names for single and double page collections"
    exit
  end

  mets_file="#{collection_path}/#{@book_id}/data/#{@book_id}_mets.xml"

  if !File.exist?(mets_file)
    puts "The file #{mets_file} for the book #{@book_id} doesn't exist"
    exit
  end
  puts mets_file
  @parser = Saxerator.parser(File.new(mets_file))


  client=Mongo::Client.new(mongodb)

  single_pages=generate_single_pages()
  double_pages=generate_double_pages(single_pages.last[:sequence].first.to_i)
#deletes a book from mongo
  client[:"#{single_pages_collection}"].find(:isPartOf => "#{@book_id}").delete_many
  client[:"#{double_pages_collection}"].find(:isPartOf => "#{@book_id}").delete_many
#adds single pages
  single_results=client[:"#{single_pages_collection}"].insert_many(single_pages)
#adds double pages
  double_results=client[:"#{double_pages_collection}"].insert_many(double_pages)
  #if (single_results[:ok]==1&&double_results[:ok]==1)
  if (single_results.validate!&&double_results.validate!)
    puts " #{single_results.inserted_count} records have been added to #{single_pages_collection} and #{double_results.inserted_count} records have been added to  #{double_pages_collection} tables in the #{mongodb} database"
  else
    puts "There are problems. Report them to Kate"
  end


