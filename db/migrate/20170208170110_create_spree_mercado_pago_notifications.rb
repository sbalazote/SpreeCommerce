class CreateSpreeMercadoPagoNotifications < ActiveRecord::Migration[5.0]
  def change
    create_table :mercado_pago_notifications do |t|
      t.string :topic
      t.string :operation_id
      t.timestamps
    end
  end
end
