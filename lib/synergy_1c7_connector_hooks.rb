class Synergy1c7ConnectorHooks < Spree::ThemeSupport::HookListener
  insert_after :admin_product_form_right, "admin/shared/code_1c_fields"

  insert_after :admin_inside_taxon_form, "admin/shared/code_1c_fields"

  insert_after :admin_configurations_sidebar_menu do
    %(<li<%== ' class="active"' if controller.controller_name == 'one_c7_connectors' %>><%= link_to t("one_c7_connector"), admin_one_c7_connector_path %></li>)
  end
  insert_after :admin_tabs do
      %(<%= tab(:one_c7_connector) %>)
  end
  insert_before :admin_dashboard do
      %(<%= link_to admin_one_c7_connector_path, :class => "button" do %>
        <span><%= t("one_c7_connector") %></span>
       <% end %>
       <br>
       <br>
       )
  end
end
