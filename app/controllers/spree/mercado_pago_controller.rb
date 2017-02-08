module Spree
  class MercadoPagoController < StoreController

    require 'mercadopago.rb'

    protect_from_forgery except: :ipn
    skip_before_filter :set_current_order, only: :ipn


    def checkout
      $mp = MercadoPago.new('8399876864756804', 'bPT7M0gEPARmuRFZnefXqaiMSAWUm1EE')

      preference_data = {
          "items": [
              {
                  "title": "testCreate",
                  "quantity": 1,
                  "unit_price": 10.2,
                  "currency_id": "ARS"
              }
          ]
      }
      payment = $mp.create_preference(preference_data)

      redirect_to payment
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
