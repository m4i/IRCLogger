require 'test_helper'

class MessagesControllerTest < ActionController::TestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:messages)
  end

  def test_should_get_channels
    get :channels, :channel => '#staff', :date => '200801'
    assert_response :success
    assert_not_nil assigns(:messages)
  end

  def test_should_get_users
    get :users, :user => 'ishihara', :date => '200801'
    assert_response :success
    assert_not_nil assigns(:messages)
  end

  def test_should_get_users
    get :search, :search => 'http://'
    assert_response :success
    assert_not_nil assigns(:messages)
  end

  def test_split_into_words
    [
      [[], []],                                         '',
      [[], ['']],                                       '""',
      [%w( foo ), []],                                  'foo',
      [%w( foo bar ), []],                              'foo bar',
      [%w( foo bar ), []],                              'foo　bar',
      [%w( bar ), %w( foo )],                           '"foo"bar',
      [%w( foo bar ), ['']],                            '""foo bar',
      [%w( foo bar ), ['', '']],                        '""foo""bar',
      [[], %w( foo\ bar )],                             '"foo bar"',
      [[], %w( foo\ bar )],                             '"foo bar',
      [%w( foo baz ), %w( bar )],                       'foo"bar"baz',
      [%w( foo bar baz ), ['', '']],                    'foo""bar""baz',
      [[], %w( foo bar\  \ baz \ quux\  )],             '"foo" "bar " " baz" " quux "',
      [[], ["f o o", "b a r ", " b a z", " q u u x "]], '"f o o" "b a r " " b a z" " q u u x "',
    ].in_groups_of(2) do |expected, string|
      assert_equal expected, @controller.send(:split_into_words, string)
    end
  end
end
