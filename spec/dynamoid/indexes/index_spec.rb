require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "Dynamoid::Indexes::Index" do

  before do
    @time = DateTime.now
    @ttl  = DateTime.now + 90
    @index = Dynamoid::Indexes::Index.new(User, [:password, :name], :range_key => :created_at)
  end

  it 'reorders keys alphabetically' do
    @index.sort([:password, :name, :created_at]).should == [:created_at, :name, :password]
  end

  it 'assigns itself hash keys' do
    @index.hash_keys.should == [:name, :password]
  end

  it 'assigns itself range keys' do
    @index.range_keys.should == [:created_at]
  end

  it 'reorders its name automatically' do
    @index.name.should == [:created_at, :name, :password]
  end

  it 'determines its own table name' do
    @index.table_name.should == 'dynamoid_tests_index_user_created_ats_and_names_and_passwords'
  end

  it 'uses a different table prefix if provided' do
    prefixed_index = Dynamoid::Indexes::Index.new(User, [:password, :name], :range_key => :created_at, :prefix => :prefixed)

    prefixed_index.table_name.should == 'dynamoid_tests_index_prefixed_created_ats_and_names_and_passwords'
  end

  it 'raises an error if a field does not exist' do
    lambda {@index = Dynamoid::Indexes::Index.new(User, [:password, :text])}.should raise_error(Dynamoid::Errors::InvalidField)
  end

  it 'returns values for indexes' do
    @index.values(:name => 'Josh', :password => 'test123', :created_at => @time).should == {:hash_value => 'Josh.test123', :range_value => @time.to_f}
  end

  it 'ignores values for fields that do not exist' do
    @index.values(:name => 'Josh', :password => 'test123', :created_at => @time, :email => 'josh@joshsymonds.com').should == {:hash_value => 'Josh.test123', :range_value => @time.to_f}
  end

  it 'substitutes a blank string for a hash value that does not exist' do
    @index.values(:name => 'Josh', :created_at => @time).should == {:hash_value => 'Josh.', :range_value => @time.to_f}
  end

  it 'ignores hash values if both hash values do not exist' do
    @index.values(:created_at => @time).should == {:range_value => @time.to_f}
  end

  it 'accepts values from an object instead of a hash' do
    @user = User.new(:name => 'Josh', :password => 'test123', :created_at => @time)

    @index.values(@user).should == {:hash_value => 'Josh.test123', :range_value => @time.to_f}
  end

  it 'accepts values from an object and returns changed values' do
    @user = User.new(:name => 'Josh', :password => 'test123', :created_at => @time)
    @user.clear_changes
    @user.name = 'Justin'

    @index.values(@user, true).should == {:hash_value => 'Josh.test123', :range_value => @time.to_f}

    @index.values(@user).should == {:hash_value => 'Justin.test123', :range_value => @time.to_f}
  end

  it 'saves an object to the index it is associated with' do
    @index = Dynamoid::Indexes::Index.new(User, :name)
    @user = User.new(:name => 'Josh', :password => 'test123', :created_at => @time, :id => 'test123')

    @index.save(@user)

    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Josh')[:ids].should == Set['test123']
  end

  it 'sets the TTL of an object that has one, on the index it is associated with' do
    @index = Dynamoid::Indexes::Index.new(User, :name)
    @user = User.new(:name => 'Josh', :password => 'test123', :created_at => @time, :id => 'test123', ttl: @ttl)

    @index.save(@user)

    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Josh')[:ttl].should == @ttl.to_f
  end

  it "doesn't set the TTL of an object that doesn't respond to it, on the index it is associated with" do
    @index = Dynamoid::Indexes::Index.new(User, :name)
    @user = User.new(:name => 'Josh', :password => 'test123', :created_at => @time, :id => 'test123', ttl: @ttl)

    def @user.respond_to?(meth, *args)
      meth == :ttl ? false : super
    end

    @index.save(@user)

    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Josh')[:ttl].should be_nil
  end

  it 'saves an object to the index it is associated with with a range' do
    @index = Dynamoid::Indexes::Index.new(User, :name, :range_key => :last_logged_in_at)
    @user = User.create(:name => 'Josh', :last_logged_in_at => @time)

    @index.save(@user)

    Dynamoid::Adapter.read("dynamoid_tests_index_user_last_logged_in_ats_and_names", 'Josh', :range_key => @time.to_f)[:ids].should == Set[@user.id]
  end

  it 'deletes an object from the index it is associated with' do
    @index = Dynamoid::Indexes::Index.new(User, :name)
    @user = User.create(:name => 'Josh', :password => 'test123', :last_logged_in_at => @time, :id => 'test123')

    @index.save(@user)
    @index.delete(@user)

    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Josh')[:ids].should be_blank
  end

  it 'updates an object by removing it from its previous index and adding it to its new one' do
    @index = Dynamoid::Indexes::Index.new(User, :name)
    @user = User.create(:name => 'Josh', :password => 'test123', :last_logged_in_at => @time, :id => 'test123')

    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Josh')[:ids].should == Set['test123']
    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Justin').should be_nil

    @user.update_attributes(:name => 'Justin')

    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Josh')[:ids].should be_blank
    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Justin')[:ids].should == Set['test123']
  end

  describe 'short-circuiting' do
    let(:hash)         { :name }
    let(:hash_2)       { :password }
    let(:hash_value)   { 'hash' }
    let(:hash_value_2) { 'hash_2' }
    let(:range)        { :created_at }
    let(:range_value)  { DateTime.now }

    let(:record) do
      User.new(
        hash   => hash_value,
        hash_2 => hash_value_2,
        range  => range_value)
    end

    describe 'hash index' do
      let(:index) { Dynamoid::Indexes::Index.new User, hash }

      describe 'when the record is new' do
        describe '#delete' do
          it 'is a no-op' do
            Dynamoid::Adapter.expects(:update_item).never
            index.delete record
          end
        end
      end

      describe "when indexed attributes haven't changed" do
        before { record.clear_changes }

        describe '#save' do
          it 'is a no-op' do
            Dynamoid::Adapter.expects(:update_item).never
            index.save record
          end
        end

        describe '#delete' do
          it 'is a no-op' do
            Dynamoid::Adapter.expects(:update_item).never
            index.delete record
          end
        end
      end
    end

    describe 'compound hash index' do
      let(:index) { Dynamoid::Indexes::Index.new User, [hash_2, hash] }

      describe 'when the record is new' do
        describe '#delete' do
          it 'is a no-op' do
            Dynamoid::Adapter.expects(:update_item).never
            index.delete record
          end
        end
      end

      describe "when indexed attributes haven't changed" do
        before { record.clear_changes }

        describe '#save' do
          it 'is a no-op' do
            Dynamoid::Adapter.expects(:update_item).never
            index.save record
          end
        end

        describe '#delete' do
          it 'is a no-op' do
            Dynamoid::Adapter.expects(:update_item).never
            index.delete record
          end
        end
      end

      describe 'when indexed attributes are changed to all nil' do
        let(:hash_value) { nil }

        before do
          record.save!
          record.password = nil
        end

        describe '#save' do
          it 'deletes the old value but does not save' do
            Dynamoid::Adapter.expects(:update_item).
              with(index.table_name, "#{hash_value}.#{hash_value_2}", {range_key: nil})
            index.save record
          end
        end

        describe '#delete' do
          it 'is a no-op' do
            Dynamoid::Adapter.expects(:update_item).never
            index.delete record
          end
        end
      end

      describe 'when all indexed attributes are no longer nil' do
        let(:hash_value)   { nil }
        let(:hash_value_2) { nil }

        before do
          record.save!
          record.password = 'hash_value_2'
        end

        describe '#save' do
          it 'saves but does not attempt to delete the old value' do
            Dynamoid::Adapter.expects(:update_item).
              with(index.table_name, "#{hash_value}.hash_value_2", {range_key: nil})
            index.save record
          end
        end
      end
    end

    describe 'hash & range index' do
      let(:index) { Dynamoid::Indexes::Index.new User, hash, range_key: range }

      describe 'when the record is new' do
        describe '#delete' do
          it 'is a no-op' do
            Dynamoid::Adapter.expects(:update_item).never
            index.delete record
          end
        end
      end

      describe "when indexed attributes haven't changed" do
        before { record.clear_changes }

        describe '#save' do
          it 'is a no-op' do
            Dynamoid::Adapter.expects(:update_item).never
            index.save record
          end
        end

        describe '#delete' do
          it 'is a no-op' do
            Dynamoid::Adapter.expects(:update_item).never
            index.delete record
          end
        end
      end
    end
  end
end
