class UpdateFixedAssets < ActiveRecord::Migration
  def change
    add_reference :purchase_items, :fixed_asset, index: true
    add_reference :fixed_assets, :product, index: true

    add_column :fixed_assets, :state, :string
    add_column :fixed_assets, :accounted_at, :datetime
    add_reference :fixed_assets, :journal_entry, index: true
    add_reference :fixed_assets, :asset_account, index: true

    # import :outstanding_assets account
    outstanding_asset_account = Account.find_or_import_from_nomenclature(:outstanding_assets)

    reversible do |r|
      r.up do
        execute 'UPDATE purchase_items pi SET fixed_asset_id = (SELECT fa.id FROM fixed_assets fa WHERE fa.purchase_item_id = pi.id LIMIT 1)'
        execute 'UPDATE fixed_assets fa SET product_id = (SELECT p.id FROM products p WHERE p.fixed_asset_id = fa.id LIMIT 1)'
        execute "UPDATE fixed_assets SET state = 'draft'"
        # set all account 21X on fixed asset from initial purchase entry item
        execute <<-SQL
          UPDATE fixed_assets AS fa
          SET asset_account_id = jei.account_id
          FROM journal_entry_items AS jei
          JOIN accounts AS a ON jei.account_id = a.id
          JOIN purchase_items AS pi ON pi.id = jei.resource_id
          WHERE jei.resource_type = 'PurchaseItem'
          AND jei.resource_prism = 'item_product'
          AND a.number LIKE '2%'
          AND fa.id = pi.fixed_asset_id
        SQL
        # replace all account (like 21X) by 23 on initial purchase entry item.
        execute <<-SQL
          UPDATE journal_entry_items AS jei
          SET account_id = (SELECT acc.id FROM accounts AS acc WHERE acc.usages = 'outstanding_assets' LIMIT 1)
          FROM purchase_items AS pi, accounts AS a
          WHERE pi.id = jei.resource_id
          AND a.id = jei.account_id
          AND jei.resource_type = 'PurchaseItem'
          AND jei.resource_prism = 'item_product'
          AND pi.fixed_asset_id IS NOT NULL
          AND a.number LIKE '2%'
        SQL
      end
      r.down do
        execute 'UPDATE fixed_assets fa SET purchase_item_id = (SELECT pi.id FROM purchase_items pi WHERE fa.id = pi.fixed_asset_id LIMIT 1)'
        execute 'UPDATE products p SET fixed_asset_id = (SELECT fa.id FROM fixed_assets fa WHERE fa.product_id = p.id LIMIT 1)'
      end
    end

    remove_column :fixed_assets, :purchase_item_id
    remove_column :fixed_assets, :purchase_id
    remove_column :products, :fixed_asset_id
  end
end
