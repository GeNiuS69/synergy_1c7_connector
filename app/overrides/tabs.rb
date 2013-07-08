Deface::Override.new(:virtual_path => 'spree/admin/shared/_configuration_menu',
                     :name => 'configuration menu',
                     :insert_bottom => "[data-hook='admin_configurations_sidebar_menu']",
                     :partial => "admin/shared/connector_menu")

#Deface::Override.new(:virtual_path => 'spree/layouts/admin',
#                     :name => 'admin tab',
#                     :insert_after => "[data-hook='admin_tabs']",
#                     :text => "<%= tab(:one_c7_connector)%>")

#Deface::Override.new(:virtual_path => 'spree/layouts/admin',
#                     :name => 'admin dashboard',
#                     :insert_after => "[data-hook='admin_dashboars']",
#                     :text => "<%= link_to admin_one_c7_connector_path, :class => 'button' do %>
#        <span><%= t('one_c7_connector') %></span>
#       <% end %>
#       <br>
#       <br>
#")

