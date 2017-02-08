module Spree
  class MercadoPagoController < StoreController

    require 'mercadopago.rb'
    require 'openssl'
    OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

    protect_from_forgery except: :ipn
    skip_before_filter :set_current_order, only: :ipn


    def checkout
      current_order.state_name == :payment || raise(ActiveRecord::RecordNotFound)
      payment_method = PaymentMethod::MercadoPagoMethod.find(params[:payment_method_id])
      payment = current_order.payments.
          create!({amount: current_order.total, payment_method: payment_method})
      payment.started_processing!


      $mp = MercadoPago.new('8989156561599790', '9auzj1s52Lu8NyNrhlq0DJSDCyItanpA')

      preference_data = {
          "items": [
              {
                  "title": "testCreate",
                  "quantity": 1,
                  "unit_price": 10.2,
                  "currency_id": "ARS"
              }],
          "back_urls": callback_urls
      }
      preference = $mp.create_preference(preference_data)

      redirect_to preference['response']['sandbox_init_point']
    end

    # Success/pending callbacks are currently aliases, this may change
    # if required.
    def success
      payment.order.next
      flash.notice = Spree.t(:order_processed_successfully)
      flash['order_completed'] = true
      redirect_to spree.order_path(payment.order)
    end

    def failure
      payment.failure!
      flash.notice = Spree.t(:payment_processing_failed)
      flash['order_completed'] = true
      redirect_to spree.checkout_state_path(state: :payment)
    end

    def ipn
      notification = MercadoPago::Notification.
        new(operation_id: params[:id], topic: params[:topic])

      if notification.save
        MercadoPago::HandleReceivedNotification.new(notification).process!
        status = :ok
      else
        status = :bad_request
      end

      render nothing: true, status: status
    end

    private

    def payment
      @payment ||= Spree::Payment.where(identifier: params[:external_reference]).
        first
    end

    def callback_urls
      @callback_urls ||= {
        success: mercado_pago_success_url,
        pending: mercado_pago_success_url,
        failure: mercado_pago_failure_url
      }
    end
  end
end
