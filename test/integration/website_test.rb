require 'test_helper'
require 'minitest/mock'

class WebsiteTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get "/"

    assert_response :success
  end

  def stub_charge_create(success: true)
    stub_create = lambda do |params|
      OpenStruct.new(
        amount: params[:amount].to_i,
        paid: success,
      )
    end
    Omise::Charge.stub(:create, stub_create) do
      yield
    end
  end

  def stub_token_retrieve
    stub_retrieve = lambda do |token|
      OpenStruct.new(
        id: token,
        card: OpenStruct.new(
          name: 'J DOE',
          last_digits: '4242',
          expiration_month: 10,
          expiration_year: 2020,
          security_code_check: false,
        )
      )
    end
    Omise::Token.stub(:retrieve, stub_retrieve) do
      yield
    end
  end

  test "that someone can't donate to no charity" do
    stub_token_retrieve do
      post donate_path, amount: "100", omise_token: "tokn_X", charity: ""
    end

    assert_template :index
    assert_equal t("website.donate.failure"), flash.now[:alert]
  end

  test "that someone can't donate 0 to a charity" do
    charity = charities(:children)

    stub_token_retrieve do
      post donate_path, amount: "0", omise_token: "tokn_X", charity: charity.id
    end

    assert_template :index
    assert_equal t("website.donate.failure"), flash.now[:alert]
  end

  test "that someone can't donate less than 20 to a charity" do
    charity = charities(:children)

    stub_token_retrieve do
      post donate_path, amount: "19", omise_token: "tokn_X", charity: charity.id
    end

    assert_template :index
    assert_equal t("website.donate.failure"), flash.now[:alert]
  end

  test "that someone can't donate without a token" do
    charity = charities(:children)
    post donate_path, amount: "100", charity: charity.id

    assert_template :index
    assert_equal t("website.donate.failure"), flash.now[:alert]
  end

  test "that someone can donate to a charity" do
    charity = charities(:children)
    initial_total = charity.total
    expected_total = initial_total + (100 * 100)

    stub_charge_create do
      post_via_redirect donate_path, amount: "100", omise_token: "tokn_X", charity: charity.id
    end

    assert_template :index
    assert_equal t("website.donate.success"), flash[:notice]
    assert_equal expected_total, charity.reload.total
  end

  test "that if the charge fail from omise side it shows an error" do
    charity = charities(:children)

    stub_charge_create(success: false) do
      post donate_path, amount: "100", omise_token: "tokn_X", charity: charity.id
    end

    assert_template :index
    assert_equal t("website.donate.failure"), flash.now[:alert]
  end

  test "that we can donate to a charity at random" do
    charities = Charity.all
    initial_total = charities.to_a.sum(&:total)
    expected_total = initial_total + (100 * 100)

    stub_charge_create do
      post donate_path, amount: "100", omise_token: "tokn_X", charity: "random"
    end

    assert_template :index
    assert_equal expected_total, charities.to_a.map(&:reload).sum(&:total)
    assert_equal t("website.donate.success"), flash[:notice]
  end
end
