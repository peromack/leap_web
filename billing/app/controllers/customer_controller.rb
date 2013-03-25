class CustomerController < ApplicationController
  before_filter :authorize

  def new
    if customer = Customer.find_by_user_id(current_user.id)
      redirect_to edit_customer_path(customer.braintree_customer_id)
    else
      @tr_data = Braintree::TransparentRedirect.
        create_customer_data(:redirect_url => confirm_customer_url)
    end
 end

  def edit
    if (params[:id] == Customer.find_by_user_id(current_user.id).braintree_customer_id)
      #current_customer.with_braintree_data!
      # @credit_card = current_customer.default_credit_card
      @braintree_data = Braintree::Customer.find(params[:id])
      @default_cc = @braintree_data.credit_cards.find { |cc| cc.default? }
      @tr_data = Braintree::TransparentRedirect.
        update_customer_data(:redirect_url => confirm_customer_url,
                             :customer_id => params[:id])
    else
      # TODO: will want to have case for admins, presumably
      access_denied
    end
  end

  def confirm
    @result = Braintree::TransparentRedirect.confirm(request.query_string)

    if @result.success?
      # customer = Customer.new(:user_id => current_user.id, :braintree_customer_id =>  @result.customer.id)
      customer = Customer.new(:braintree_customer_id =>  @result.customer.id)
      customer.user = current_user
      customer.save
      #current_user.save!
      render :action => "confirm"
    #elsif current_user.has_payment_info?
    elsif (customer = Customer.find_by_user_id(current_user.id)) and customer.has_payment_info?
      customer.with_braintree_data! #todo
      render :action => "edit"
    else
      render :action => "new"
    end
  end
end