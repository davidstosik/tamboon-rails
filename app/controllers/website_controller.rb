class WebsiteController < ApplicationController
  rescue_from Omise::Error, with: :failure

  def index
    @token = nil
  end

  def donate
    return failure unless params[:omise_token].present?

    charity = get_charity
    amount = get_amount

    unless charity && amount && amount > 2000
      @token = retrieve_token(params[:omise_token])
      failure
      return
    end

    charge = Omise::Charge.create({
      amount: amount,
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
    amount_s = params.fetch(:amount, '').strip
    amount_f = Float(amount_s) * 100
    amount_i = amount_f.to_i
    if amount_i == amount_f
      amount_i
    else
      nil
    end
  rescue ArgumentError
    nil
  end

  def get_charity
    if params[:charity] == 'random'
      Charity.random
    else
      Charity.find_by(id: params[:charity])
    end
  end
end
