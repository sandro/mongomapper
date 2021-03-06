require 'test_helper'

class ValidationsTest < Test::Unit::TestCase
  context "Saving a new document that is invalid" do
    setup do
      @document = Class.new do
        include MongoMapper::Document
        key :name, String, :required => true
      end
      @document.collection.clear
    end
    
    should "not insert document" do
      doc = @document.new
      doc.save
      @document.count.should == 0
    end
    
    should "populate document's errors" do
      doc = @document.new
      doc.errors.size.should == 0
      doc.save
      doc.errors.full_messages.should == ["Name can't be empty"]
    end
  end
  
  context "Saving a document that is invalid (destructive)" do
    setup do
      @document = Class.new do
        include MongoMapper::Document
        key :name, String, :required => true
      end
      @document.collection.clear
    end
    
    should "raise error" do
      doc = @document.new
      lambda { doc.save! }.should raise_error(MongoMapper::DocumentNotValid)
    end
  end
  
  context "Saving an existing document that is invalid" do
    setup do
      @document = Class.new do
        include MongoMapper::Document
        key :name, String, :required => true
      end
      @document.collection.clear
      
      @doc = @document.create(:name => 'John Nunemaker')
    end
    
    should "not update document" do
      @doc.name = nil
      @doc.save
      @document.find(@doc.id).name.should == 'John Nunemaker'
    end
    
    should "populate document's errors" do
      @doc.name = nil
      @doc.save
      @doc.errors.full_messages.should == ["Name can't be empty"]
    end
  end

  context "Saving a new document with invalid embedded documents" do
    setup do
      ::Location = Class.new do
        include MongoMapper::EmbeddedDocument
        key :city, :required => true
      end

      ::Battery = Class.new do
        include MongoMapper::EmbeddedDocument
        key :capacity, :required => true
      end

      ::Phone = Class.new do
        include MongoMapper::EmbeddedDocument
        key :number, :required => true
        many :batteries
      end

      @document = Class.new do
        include MongoMapper::Document
        many :locations
        many :phones
      end
      @document.collection.clear
    end

    teardown do
      Object.send(:remove_const, :Location)
      Object.send(:remove_const, :Battery)
      Object.send(:remove_const, :Phone)
    end

    should "not insert document with invalid address" do
      doc = @document.new :locations => [Location.new]
      doc.save.should be_false
      @document.count.should == 0
    end

    should "populate document's errors with the errors of Location" do
      doc = @document.new :locations => [Location.new]
      doc.save.should be_false
      doc.errors.size.should == 1
      doc.errors.full_messages.should == ["Location city can't be empty"]
    end

    should "populate document's errors with the errors of Location and Phone" do
      doc = @document.new :locations => [Location.new], :phones => [Phone.new]
      doc.save.should be_false
      doc.errors.size.should == 2
      doc.errors.full_messages.should include("Location city can't be empty")
      doc.errors.full_messages.should include("Phone number can't be empty")
    end

    should "populate document's errors with deeply nested errors" do
      phone = Phone.new :batteries => [Battery.new]
      doc = @document.new :locations => [Location.new], :phones => [phone]
      doc.save.should be_false
      doc.errors.size.should == 3
      doc.errors.full_messages.should include("Location city can't be empty")
      doc.errors.full_messages.should include("Phone number can't be empty")
      doc.errors.full_messages.should include("Battery capacity can't be empty")
    end
  end

  context "Adding validation errors" do
    setup do
      @document = Class.new do
        include MongoMapper::Document
        key :action, String
        def action_present
          errors.add(:action, 'is invalid') if action.blank?
        end
      end
      @document.collection.clear
    end
    
    should "work with validate_on_create callback" do
      @document.validate_on_create :action_present
      
      doc = @document.new
      doc.action = nil
      doc.should have_error_on(:action)
      
      doc.action = 'kick'
      doc.should_not have_error_on(:action)
      doc.save
      
      doc.action = nil
      doc.should_not have_error_on(:action)
    end
    
    should "work with validate_on_update callback" do
      @document.validate_on_update :action_present
      
      doc = @document.new
      doc.action = nil
      doc.should_not have_error_on(:action)
      doc.save
      
      doc.action = nil
      doc.should have_error_on(:action)
      
      doc.action = 'kick'
      doc.should_not have_error_on(:action)
    end
  end
  
  context "validating uniqueness of" do
    setup do
      @document = Class.new do
        include MongoMapper::Document
        key :name, String
        validates_uniqueness_of :name
      end
      @document.collection.clear
    end

    should "not fail if object is new" do
      doc = @document.new
      doc.should_not have_error_on(:name)
    end

    should "allow to update an object" do
      doc = @document.new("name" => "joe")
      doc.save.should be_true

      @document \
        .stubs(:find) \
        .with(:first, :conditions => {:name => 'joe'}, :limit => 1) \
        .returns(doc)

      doc.name = "joe"
      doc.valid?.should be_true
      doc.should_not have_error_on(:name)
    end

    should "fail if object name is not unique" do
      doc = @document.new("name" => "joe")
      doc.save.should be_true

      @document \
        .stubs(:find) \
        .with(:first, :conditions => {:name => 'joe'}, :limit => 1) \
        .returns(doc)

      doc2 = @document.new("name" => "joe")
      doc2.should have_error_on(:name)
    end
  end
  
  context "validates uniqueness of with :unique shortcut" do
    should "work" do
      @document = Class.new do
        include MongoMapper::Document
        key :name, String, :unique => true
      end
      @document.collection.clear
      
      doc = @document.create(:name => 'John')
      doc.should_not have_error_on(:name)
      
      @document \
        .stubs(:find) \
        .with(:first, :conditions => {:name => 'John'}, :limit => 1) \
        .returns(doc)
      
      second_john = @document.create(:name => 'John')
      second_john.should have_error_on(:name, 'has already been taken')
    end
  end
end
