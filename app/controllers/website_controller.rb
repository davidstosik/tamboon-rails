class WebsiteController < ApplicationController
  rescue_from Omise::Error, with: :failure

  def index
    @token = nil
  end

  def donate
    return failure unless params[:omise_token].present?

    charity = Charity.find_by(id: params[:charity])

    amount = get_amount
    unless charity && amount && amount > 20
      @token = retrieve_token(params[:omise_token])
      failure
      return
    end

    charge = Omise::Charge.create({
      amount: amount * 100,
      currency: "THB",
      card: params[:omise_token],
      description: "Donation to #{charity.name} [#{charity.id}]",
    })

    return failure unless charge.paid

    charity.credit_amount(charge.amount)
    flash.notice = t(".success")
    redirect_to root_path
  end

  private

  def retrieve_token(token)
    Omise::Token.retrieve(token)
  end

  def failure
    flash.now.alert = t(".failure")
    render :index
  end

  def get_amount
    amount_str = params.fetch(:amount, '').strip
    Integer(amount_str)
  rescue ArgumentError
    nil
  end
end
