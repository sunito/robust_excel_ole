# example 7: open, close, save  with giving control to Excel 

require File.join(File.dirname(__FILE__), '../lib/robust_excel_ole')

module RobustExcelOle

    ExcelApp.close_all
    begin
	  file_name = '../spec/data/simple.xls' 
	  book = RobustExcelOle::Book.open(file_name, :visible => true)          # open a book
	  ExcelApp.reuse_if_possible.Visible = true                              # make Excel visible 
	  sleep 1
	  sheet = book[0]                                                        # access a sheet
	  sheet[0,0] = sheet[0,0].value == "simple" ? "complex" : "simple"       # change a cell
	  sleep 1
	  begin
	    new_book = RobustExcelOle::Book.open(file_name, :if_unsaved => :excel) # open another book with the same file name 
	  rescue ExcelUserCanceled => msg                                          # if the user chooses not open the book,
	  	puts "#{msg.message}"                                                  #   an exeptions is raised
	  end
	  puts "new book has opened" if new_book
	  ExcelApp.reuse_if_possible.Visible = true
	  begin
	  	book.close(:if_unsaved => :excel)                              # close the unsaved book. 
	  rescue ExcelUserCanceled => msg                                  # user is asked whether the unsaved book shall be saved
	  	puts "#{msg.message}"                                          # if the user chooses to cancel, then an expeption is raised
	  end
	  if new_book then
	  	begin
	  	  new_book.save_as(file_name, :if_exists => :excel)            # save the new book, if it was opened
	  	rescue ExcelErrorSave => msg                                    # user is asked, whether the existing file shall be overwritten
	  	  puts "save_as: #{msg.message}"                               # if the user chooses "no" or "cancel", an exception is raised
	  	end 

	  	new_book.close                                         # close the new book, if the user chose to open it
	  end
	ensure                                                              
  	  ExcelApp.close_all                                    # close workbooks, quit Excel application
	end

end