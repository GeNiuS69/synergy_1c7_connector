#encoding: UTF-8
module Spree
class Admin::OneC7ConnectorsController < Admin::BaseController
    def show

    end
    def create
        if params[:connector][:type]=='1c'
            file = params[:connector][:file]
            File.open(Rails.root.join('public','uploads',file.original_filename),'wb') do |f|
                f.write(file.read)
            end
            Connector1cWorker.perform_async(file.original_filename)
            redirect_to admin_one_c7_connector_path, :notice => t(:successful_1c_import)
        elsif params[:connector][:type]=='excel'
            params[:connector][:files].each do |file|
                File.open(Rails.root.join('public','uploads',file.original_filename),'wb') do |f|
                    f.write(file.read)
                end
                ConnectorxlsWorker.perform_async(file.original_filename)
            end
            redirect_to admin_one_c7_connector_path, :notice => t(:successful_1c_import)
        else
            redirect_to admin_one_c7_connector_path, :notice => t(:fail_1c_import)
        end
    end

    def discharge
        @one_c_connector = Synergy1c7Connector::Connection.new
        @order = Order.find_by_number(params[:id])
        @one_c_connector.discharge(@order)
        redirect_to edit_admin_order_path(@order), :notice => t(:succesful_1c_discharge)
    end
end
end
