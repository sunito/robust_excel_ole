# -*- coding: utf-8 -*-

require File.join(File.dirname(__FILE__), './spec_helper')


$VERBOSE = nil

include RobustExcelOle

describe Book do

  before(:all) do
    excel = Excel.new(:reuse => true)
    open_books = excel == nil ? 0 : excel.Workbooks.Count
    puts "*** open books *** : #{open_books}" if open_books > 0
    Excel.close_all
  end

  before do
    @dir = create_tmpdir
    @simple_file = @dir + '/workbook.xls'
    @simple_save_file = @dir + '/workbook_save.xls'
    @different_file = @dir + '/different_workbook.xls'
    @simple_file_other_path = @dir + '/more_data/workbook.xls'
    @another_simple_file = @dir + '/another_workbook.xls'
    @linked_file = @dir + '/workbook_linked.xlsm'
    @simple_file_xlsm = @dir + '/workbook.xls'
    @simple_file_xlsx = @dir + '/workbook.xlsx'
  end

  after do
    Excel.close_all
    rm_tmp(@dir)
  end

  describe "create file" do
    context "with standard" do
      it "open an existing file" do
        expect {
          @book = Book.new(@simple_file)
        }.to_not raise_error
        @book.should be_a Book
        @book.close
      end
    end
  end

  describe "open" do

    context "with various file formats" do

      it "should open linked workbook" do
        book = Book.open(@linked_file, :visible => true)
        book.close
      end

      it "should open xlsm file" do
        book = Book.open(@simple_file_xlsm, :visible => true)
        book.close
      end
    end

    context "with standard options" do
      before do
        @book = Book.open(@simple_file)
      end

      after do
        @book.close
      end

      it "should say that it lives" do
        @book.should be_alive
      end
    end

    context "with identity transperence" do

      before do
        @book = Book.open(@simple_file)
      end

      after do
        @book.close
      end

      it "should yield identical Book objects for identical Excel books when reopening" do
        @book.should be_alive
        @book.close
        @book.should_not be_alive
        book2 = Book.open(@simple_file)
        book2.should === @book
        book2.should be_alive
        book2.close
      end

      it "should yield different Book objects when reopening in a new Excel" do
        @book.should be_alive
        old_excel = @book.excel
        @book.close
        @book.should_not be_alive
        book2 = Book.open(@simple_file, :force_excel => :new)
        book2.should_not === @book
        book2.should be_alive
        book2.excel.should_not == old_excel
        book2.close
      end
    end

    context "with :force_excel" do

      before do
        @book = Book.open(@simple_file)
      end

      after do
        @book.close rescue nil
      end

      it "should open in a new Excel" do
        book2 = Book.open(@simple_file, :force_excel => :new)
        book2.should be_alive
        book2.should be_a Book
        book2.excel.should_not == @book.excel 
        book2.should_not == @book
        @book.Readonly.should be_false
        book2.Readonly.should be_true
        book2.close
      end

      it "should open in a given Excel, provide identity transparency, because book can be readonly, such that the old and the new book are readonly" do
        book2 = Book.open(@simple_file, :force_excel => :new)
        book2.excel.should_not == @book.excel
        book3 = Book.open(@simple_file, :force_excel => :new)
        book3.excel.should_not == book2.excel
        book3.excel.should_not == @book.excel
        book2.close
        book3.close
        @book.close
        book4 = Book.open(@simple_file, :force_excel => book2.excel, :read_only => true)
        book4.should be_alive
        book4.should be_a Book
        book4.excel.should == book2.excel
        book4.ReadOnly.should be_true
        book4.should == book2
        book4.close
        book5 = Book.open(@simple_file, :force_excel => book2, :read_only => true)
        book5.should be_alive
        book5.should be_a Book
        book5.excel.should == book2.excel
        book5.ReadOnly.should be_true
        book5.should == book2
        book5.close
        book3.close
      end
    end

    context "with :default_excel" do

      before do
        excel = Excel.new(:reuse => false)
        @book = Book.open(@simple_file)
      end

      after do
        @book.close rescue nil
      end

      it "should reopen the book in the excel instance where it was opened before" do
        excel = Excel.new(:reuse => false)
        @book.close
        book2 = Book.open(@simple_file)
        book2.should be_alive
        book2.should be_a Book
        book2.excel.should == @book.excel
        book2.excel.should_not == excel
        book2.filename.should == @book.filename
        @book.should be_alive
        book2.should == @book
        book2.close
      end

      it "should open a new excel, if the book cannot be reopened" do
        @book.close
        new_excel = Excel.new(:reuse => false)
        book2 = Book.open(@different_file, :default_excel => :new)
        book2.should be_alive
        book2.should be_a Book
        book2.excel.should_not == new_excel
        book2.excel.should_not == @book.excel
        book2.close
      end
    end

    context "with :if_unsaved" do

      before do
        @book = Book.open(@simple_file)
        @sheet = @book[0]
        @book.add_sheet(@sheet, :as => 'a_name')
      end

      after do
        @book.close(:if_unsaved => :forget)
        @new_book.close rescue nil
      end

      it "should raise an error, if :if_unsaved is :raise" do
        expect {
          @new_book = Book.open(@simple_file, :if_unsaved => :raise)
        }.to raise_error(ExcelErrorOpen, "book is already open but not saved (#{File.basename(@simple_file)})")
      end

      it "should let the book open, if :if_unsaved is :accept" do
        expect {
          @new_book = Book.open(@simple_file, :if_unsaved => :accept)
          }.to_not raise_error
        @book.should be_alive
        @new_book.should be_alive
        @new_book.should == @book
      end

      context "with :if_unsaved => :alert" do
        before do
         @key_sender = IO.popen  'ruby "' + File.join(File.dirname(__FILE__), '/helpers/key_sender.rb') + '" "Microsoft Office Excel" '  , "w"
        end

        after do
          @key_sender.close
        end

        it "should open the new book and close the unsaved book, if user answers 'yes'" do
          # "Yes" is the  default. --> language independent
          @key_sender.puts "{enter}"
          @new_book = Book.open(@simple_file, :if_unsaved => :alert)
          @new_book.should be_alive
          @new_book.filename.downcase.should == @simple_file.downcase
          @book.should_not be_alive
        end

        it "should not open the new book and not close the unsaved book, if user answers 'no'" do
          # "No" is right to "Yes" (the  default). --> language independent
          # strangely, in the "no" case, the question will sometimes be repeated three times
          #@book.excel.Visible = true
          @key_sender.puts "{right}{enter}"
          @key_sender.puts "{right}{enter}"
          @key_sender.puts "{right}{enter}"
          expect{
            Book.open(@simple_file, :if_unsaved => :alert)
            }.to raise_error(ExcelErrorOpen, "open: user canceled or open error")
          @book.should be_alive
        end
      end
    end

    context "with :if_obstructed" do

      for i in 1..2 do

        context "with and without reopen" do

          before do        
            if i == 1 then 
              book_before = Book.open(@simple_file)
              book_before.close
            end
            @book = Book.open(@simple_file_other_path)
            @sheet_count = @book.workbook.Worksheets.Count
            @sheet = @book[0]
            @book.add_sheet(@sheet, :as => 'a_name')
          end

          after do
            @book.close(:if_unsaved => :forget)
            @new_book.close rescue nil
          end

          it "should save the old book, close it, and open the new book, if :if_obstructed is :save" do
            @new_book = Book.open(@simple_file, :if_obstructed => :save)
            @book.should_not be_alive
            @new_book.should be_alive
            @new_book.filename.downcase.should == @simple_file.downcase
            old_book = Book.open(@simple_file_other_path, :if_obstructed => :forget)
            old_book.workbook.Worksheets.Count.should ==  @sheet_count + 1
            old_book.close
          end

          it "should raise an error, if the old book is unsaved, and close the old book and open the new book, 
              if :if_obstructed is :close_if_saved" do
            expect{
              @new_book = Book.open(@simple_file, :if_obstructed => :close_if_saved)
            }.to raise_error(ExcelErrorOpen, "book with the same name in a different path is unsaved: workbook.xls")
            @book.save
            @new_book = Book.open(@simple_file, :if_obstructed => :close_if_saved)
            @book.should_not be_alive
            @new_book.should be_alive
            @new_book.filename.downcase.should == @simple_file.downcase
            old_book = Book.open(@simple_file_other_path, :if_obstructed => :forget)
            old_book.workbook.Worksheets.Count.should ==  @sheet_count + 1
            old_book.close
          end
        end
      end
    end

    context "with non-existing file" do

      it "should create a workbook" do
        File.delete @simple_save_file rescue nil
        book = Book.open(@simple_save_file, :if_absent => :create)
        book.should be_a Book
        book.close
        File.exist?(@simple_save_file).should be_true
      end

      it "should raise an exception by default" do
        File.delete @simple_save_file rescue nil
        expect {
          Book.open(@simple_save_file)
        }.to raise_error(ExcelErrorOpen, "file #{@simple_save_file} not found")
      end
    end

    context "with :read_only" do
      
      it "should reopen the book with writable (unsaved changes from readonly will not be saved)" do
        book = Book.open(@simple_file, :read_only => true)
        book.ReadOnly.should be_true
        book.should be_alive
        sheet = book[0]
        old_cell_value = sheet[1,1].value
        sheet[1,1] = sheet[1,1].value == "foo" ? "bar" : "foo"
        book.Saved.should be_false
        new_book = Book.open(@simple_file, :read_only => false, :if_unsaved => :accept)
        new_book.ReadOnly.should be_false 
        new_book.should be_alive
        book.should be_alive   
        new_book.should == book 
        new_sheet = new_book[0]
        new_cell_value = new_sheet[1,1].value
        new_cell_value.should == old_cell_value
      end

    context "with block" do
      it 'block parameter should be instance of Book' do
        Book.open(@simple_file) do |book|
          book.should be_a Book
        end
      end
    end
  end

  describe "reopen" do

    context "with standard" do
      
      before do
        @book = Book.open(@simple_file)
      end

      after do
        @book.close
      end

      it "should reopen the closed book" do
        @book.should be_alive
        book1 = @book
        @book.close
        @book.should_not be_alive
        @book.reopen
        @book.should be_a Book
        @book.should be_alive
        @book.should === book1
      end
    end
  end

  describe "send methods to workbook" do

    context "with standard" do
      before do
        @book = Book.open(@simple_file)
      end

      after do
        @book.close
      end

      it "should send Saved to workbook" do
        @book.Saved.should be_true
      end

      it "should send Fullname to workbook" do
        @book.Fullname.tr('\\','/').should == @simple_file
      end
    end
  end

  describe "hidden_excel" do
    
    context "with some open book" do

      before do
        @book = Book.open(@simple_file)
      end

      after do
        @book.close
      end

      it "should create and use a hidden Excel instance" do
        book2 = Book.open(@simple_file, :force_excel => @book.bookstore.hidden_excel)
        book2.excel.should_not == @book.excel
        book2.excel.visible.should be_false
        book2.excel.displayalerts.should be_false
        book2.close 
      end
    end
  end

  describe "nvalue, set_nvalue, rename_range" do
    
    context "nvalue, book[<name>]" do
    
      before do
        @book1 = Book.open(@another_simple_file)
      end

      after do
        @book1.close(:if_unsaved => :forget)
      end   

      it "should return value of a range" do
        @book1.nvalue("new").should == "foo"
        @book1.nvalue("one").should == 1
        @book1.nvalue("firstrow").should == [[1,2]]        
        @book1.nvalue("four").should == [[1,2],[3,4]]
        @book1.nvalue("firstrow").should_not == "12"
        @book1.nvalue("firstcell").should == "foo"
        @book1["new"].should == "foo"
        @book1["one"].should == 1
        @book1["firstrow"].should == [[1,2]]        
        @book1["four"].should == [[1,2],[3,4]]        
        @book1["firstcell"].should == "foo"
      end
    end

    context "set_nvalue, book[<name>]=" do
    
      before do
        @book1 = Book.open(@another_simple_file)
      end

      after do
        @book1.close(:if_unsaved => :forget)
      end   

      it "should set value of a range" do
        @book1.nvalue("new").should == "foo"
        @book1.set_nvalue("new","bar")
        @book1.nvalue("new").should == "bar"
      end

      it "should set value of a range" do
        @book1.nvalue("new").should == "foo"
        @book1["new"] = "bar"
        @book1.nvalue("new").should == "bar"
      end
    end
  end

  describe "close" do

    context "with unsaved read_only book" do
      before do
        @book = Book.open(@simple_file, :read_only => true)
        @sheet_count = @book.workbook.Worksheets.Count
        @book.add_sheet(@sheet, :as => 'a_name')
      end

      it "should close the unsaved book without error and without saving" do
        expect{
          @book.close
          }.to_not raise_error
        new_book = Book.open(@simple_file)
        new_book.workbook.Worksheets.Count.should ==  @sheet_count
        new_book.close
      end
    end

    context "with unsaved book" do
      before do
        @book = Book.open(@simple_file)
        @sheet_count = @book.workbook.Worksheets.Count
        @book.add_sheet(@sheet, :as => 'a_name')
        @sheet = @book[0]
      end

      after do
        @book.close(:if_unsaved => :forget) rescue nil
      end

      it "should raise error by default" do
        expect{
          @book.close(:if_unsaved => :raise)
        }.to raise_error(ExcelErrorClose, "book is unsaved (#{File.basename(@simple_file)})")
      end

      it "should save the book before close with option :save" do
        ole_workbook = @book.workbook
        excel = @book.excel
        expect {
          @book.close(:if_unsaved => :save)
        }.to change {excel.Workbooks.Count }.by(-1)
        @book.workbook.should == nil
        @book.should_not be_alive
        expect{
          ole_workbook.Name}.to raise_error(WIN32OLERuntimeError)
        new_book = Book.open(@simple_file)
        begin
          new_book.workbook.Worksheets.Count.should == @sheet_count + 1
        ensure
          new_book.close
        end
      end
    end
  end

  describe "save" do

    context "with simple save" do
      
      it "should save for a file opened without :read_only" do
        @book = Book.open(@simple_file)
        @book.add_sheet(@sheet, :as => 'a_name')
        @new_sheet_count = @book.workbook.Worksheets.Count
        expect {
          @book.save
        }.to_not raise_error
        @book.workbook.Worksheets.Count.should ==  @new_sheet_count
        @book.close
      end
    end

    context "with open with read only" do
      before do
        @book = Book.open(@simple_file, :read_only => true)
      end

      after do
        @book.close
      end

      it {
        expect {
          @book.save_as(@simple_file)
        }.to raise_error(IOError,
                     "Not opened for writing(open with :read_only option)")
      }
    end

    context "with argument" do
      before do
        Book.open(@simple_file) do |book|
          book.save_as(@simple_save_file, :if_exists => :overwrite)
        end
      end

      it "should save to 'simple_save_file.xlsx'" do
        File.exist?(@simple_save_file).should be_true
      end
    end

    context "with different extensions" do
      before do
        @book = Book.open(@simple_file)
      end

      after do
        @book.close
      end

      possible_extensions = ['xls', 'xlsm', 'xlsx']
      possible_extensions.each do |extensions_value|
        it "should save to 'simple_save_file.#{extensions_value}'" do
          simple_save_file = @dir + '/simple_save_file.' + extensions_value
          File.delete simple_save_file rescue nil
          @book.save_as(simple_save_file, :if_exists => :overwrite)
          File.exist?(simple_save_file).should be_true
          new_book = Book.open(simple_save_file)
          new_book.should be_a Book
          new_book.close
        end
      end
    end

    # options :overwrite, :raise, :excel, no option, invalid option
    possible_displayalerts = [true, false]
    possible_displayalerts.each do |displayalert_value|
      context "with displayalerts=#{displayalert_value}" do
        before do
          @book = Book.open(@simple_file, :displayalerts => displayalert_value)
        end

        after do
          @book.close
        end

        it "should raise an error if the book is open" do
          File.delete @simple_save_file rescue nil
          FileUtils.copy @simple_file, @simple_save_file
          book_save = Book.open(@simple_save_file, :excel => :new)
          expect{
            @book.save_as(@simple_save_file, :if_exists => :overwrite)
            }.to raise_error(ExcelErrorSave, "book is open and used in Excel")
          book_save.close
        end

        context "with :if_exists => :alert" do
          before do
            File.delete @simple_save_file rescue nil
            File.open(@simple_save_file,"w") do | file |
              file.puts "garbage"
            end
            @garbage_length = File.size?(@simple_save_file)
            @key_sender = IO.popen  'ruby "' + File.join(File.dirname(__FILE__), '/helpers/key_sender.rb') + '" "Microsoft Excel" '  , "w"
          end

          after do
            @key_sender.close
          end

          it "should save if user answers 'yes'" do
            # "Yes" is to the left of "No", which is the  default. --> language independent
            @key_sender.puts "{left}{enter}" #, :initial_wait => 0.2, :if_target_missing=>"Excel window not found")
            @book.save_as(@simple_save_file, :if_exists => :alert)
            File.exist?(@simple_save_file).should be_true
            File.size?(@simple_save_file).should > @garbage_length
            @book.excel.DisplayAlerts.should == displayalert_value
            new_book = Book.open(@simple_save_file, :excel => :new)
            new_book.should be_a Book
            new_book.close
            @book.excel.DisplayAlerts.should == displayalert_value
          end

          it "should not save if user answers 'no'" do
            # Just give the "Enter" key, because "No" is the default. --> language independent
            # strangely, in the "no" case, the question will sometimes be repeated three times
            @key_sender.puts "{enter}"
            @key_sender.puts "{enter}"
            @key_sender.puts "{enter}"
            #@key_sender.puts "%{n}" #, :initial_wait => 0.2, :if_target_missing=>"Excel window not found")
            expect{
              @book.save_as(@simple_save_file, :if_exists => :alert)
              }.to raise_error(ExcelErrorSave, "not saved or canceled by user")
            File.exist?(@simple_save_file).should be_true
            File.size?(@simple_save_file).should == @garbage_length
            @book.excel.DisplayAlerts.should == displayalert_value
          end

          it "should not save if user answers 'cancel'" do
            # 'Cancel' is right from 'yes'
            # strangely, in the "no" case, the question will sometimes be repeated three times
            @key_sender.puts "{right}{enter}"
            @key_sender.puts "{right}{enter}"
            @key_sender.puts "{right}{enter}"
            #@key_sender.puts "%{n}" #, :initial_wait => 0.2, :if_target_missing=>"Excel window not found")
            expect{
              @book.save_as(@simple_save_file, :if_exists => :alert)
              }.to raise_error(ExcelErrorSave, "not saved or canceled by user")
            File.exist?(@simple_save_file).should be_true
            File.size?(@simple_save_file).should == @garbage_length
            @book.excel.DisplayAlerts.should == displayalert_value
          end
        end
      end
    end
  end

  describe "alive?, filename, ==, visible, displayalerts, activate, saved" do

    context "with alive?" do

      before do
        @book = Book.open(@simple_file)
      end

      after do
        @book.close
      end

      it "should return true, if book is alive" do
        @book.should be_alive
      end

      it "should return false, if book is dead" do
        @book.close
        @book.should_not be_alive
      end

    end

    context "with filename" do

      before do
        @book = Book.open(@simple_file)
      end

      after do
        @book.close
      end

      it "should return full file name" do
        @book.filename.should == @simple_file
      end

    end

    context "with ==" do

      before do
        @book = Book.open(@simple_file)
      end

      after do
        @book.close
        @new_book.close rescue nil
      end

      it "should be true with two identical books" do
        @new_book = Book.open(@simple_file)
        @new_book.should == @book
      end

      it "should be false with two different books" do
        @new_book = Book.new(@different_file)
        @new_book.should_not == @book
      end

      it "should be false with same book names but different paths" do       
        @new_book = Book.new(@simple_file_other_path, :excel => :new)
        @new_book.should_not == @book
      end
    end

    context "with activate" do

      before do
        @key_sender = IO.popen  'ruby "' + File.join(File.dirname(__FILE__), '/helpers/key_sender.rb') + '" "Microsoft Office Excel" '  , "w"        
        @book = Book.open(@simple_file, :visible => true)
        @book2 = Book.open(@another_simple_file, :force_excel => :new, :visible => true)
      end

      after do
        @book.close(:if_unsaved => :forget)
        @book2.close(:if_unsaved => :forget)
        @key_sender.close
      end

      it "should activate a book" do
        sheet = @book[1]
        sheet.Activate
        sheet[2,3].Activate
        sheet2 = @book2[2]
        sheet2.Activate
        sheet2[3,2].Activate
        Excel.current.should == @book.excel
        @book2.activate
        @key_sender.puts "{a}{enter}"
        sleep 1
        sheet2[3,2].Value.should == "a"
        #Excel.current.should == @book2.excel
        @book.activate
        @key_sender.puts "{a}{enter}"
        sleep 1
        sheet[2,3].Value.should == "a"
        Excel.current.should == @book.excel
      end
    end
  end

  describe "#add_sheet" do
    before do
      @book = Book.open(@simple_file)
      @sheet = @book[0]
    end

    after do
      @book.close(:if_unsaved => :forget)
    end

    context "only first argument" do
      it "should add worksheet" do
        expect { @book.add_sheet @sheet }.to change{ @book.workbook.Worksheets.Count }.from(3).to(4)
      end

      it "should return copyed sheet" do
        sheet = @book.add_sheet @sheet
        copyed_sheet = @book.workbook.Worksheets.Item(@book.workbook.Worksheets.Count)
        sheet.name.should eq copyed_sheet.name
      end
    end

    context "with first argument" do
      context "with second argument is {:as => 'copyed_name'}" do
        it "copyed sheet name should be 'copyed_name'" do
          @book.add_sheet(@sheet, :as => 'copyed_name').name.should eq 'copyed_name'
        end
      end

      context "with second argument is {:before => @sheet}" do
        it "should add the first sheet" do
          @book.add_sheet(@sheet, :before => @sheet).name.should eq @book[0].name
        end
      end

      context "with second argument is {:after => @sheet}" do
        it "should add the first sheet" do
          @book.add_sheet(@sheet, :after => @sheet).name.should eq @book[1].name
        end
      end

      context "with second argument is {:before => @book[2], :after => @sheet}" do
        it "should arguments in the first is given priority" do
          @book.add_sheet(@sheet, :before => @book[2], :after => @sheet).name.should eq @book[2].name
        end
      end
    end

    context "without first argument" do
      context "second argument is {:as => 'new sheet'}" do
        it "should return new sheet" do
          @book.add_sheet(:as => 'new sheet').name.should eq 'new sheet'
        end
      end

      context "second argument is {:before => @sheet}" do
        it "should add the first sheet" do
          @book.add_sheet(:before => @sheet).name.should eq @book[0].name
        end
      end

      context "second argument is {:after => @sheet}" do
        it "should add the second sheet" do
          @book.add_sheet(:after => @sheet).name.should eq @book[1].name
        end
      end
    end

    context "without argument" do
      it "should add empty sheet" do
        expect { @book.add_sheet }.to change{ @book.workbook.Worksheets.Count }.from(3).to(4)
      end

      it "should return copyed sheet" do
        sheet = @book.add_sheet
        copyed_sheet = @book.workbook.Worksheets.Item(@book.workbook.Worksheets.Count)
        sheet.name.should eq copyed_sheet.name
      end
    end
  end

  describe 'access sheet' do
    before do
      @book = Book.open(@simple_file)
    end

    after do
      @book.close
    end

    context "standard" do

      it 'with sheet name' do
        @book['Sheet1'].should be_kind_of Sheet
      end

      it 'with integer' do
        @book[0].should be_kind_of Sheet
      end

      it 'with block' do
        @book.each do |sheet|
          sheet.should be_kind_of Sheet
        end
      end
    end

    context 'open with block' do
      it {
        Book.open(@simple_file) do |book|
          book['Sheet1'].should be_a Sheet
        end
      }
    end
  end
end
end
