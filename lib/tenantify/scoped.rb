# frozen_string_literal: true

module Tenantify
  module Scoped
    extend ActiveSupport::Concern

    class_methods do
      def belongs_to_tenant(association_name, options = {})
        class_attribute :tenant_association_name
        self.tenant_association_name = association_name

        # Ensure the association exists
        belongs_to association_name, **options

        # Apply default scope to filter by tenant
        default_scope -> {
          if Tenantify.tenant_scoped? && Tenantify.current_tenant
            fk = reflect_on_association(association_name)&.foreign_key || "#{association_name}_id"
            where(fk => Tenantify.current_tenant.id)
          else
            all
          end
        }

        # Automatically assign tenant on create
        before_validation :set_tenant_automatically, on: :create

        # Validate that the tenant is not changed
        validate :validate_tenant_not_changed, on: :update

        # Validate cross-tenant associations
        validate :validate_cross_tenant_associations
      end
    end

    private

    def set_tenant_automatically
      return unless self.class.tenant_association_name
      fk = self.class.reflect_on_association(self.class.tenant_association_name)&.foreign_key || "#{self.class.tenant_association_name}_id"
      if send(fk).nil? && Tenantify.current_tenant
        send("#{self.class.tenant_association_name}=", Tenantify.current_tenant)
      end
    end

    def validate_tenant_not_changed
      return unless self.class.tenant_association_name
      fk = self.class.reflect_on_association(self.class.tenant_association_name)&.foreign_key || "#{self.class.tenant_association_name}_id"
      if send("#{fk}_changed?") && send("#{fk}_was") != nil
        errors.add(fk, "cannot be changed after creation")
      end
    end

    def validate_cross_tenant_associations
      return unless self.class.tenant_association_name
      
      self.class.reflect_on_all_associations(:belongs_to).each do |assoc|
        next if assoc.name == self.class.tenant_association_name
        
        associated_class = assoc.klass
        if associated_class.respond_to?(:tenant_association_name)
          associated_record = send(assoc.name)
          next if associated_record.nil?
          
          my_fk = self.class.reflect_on_association(self.class.tenant_association_name)&.foreign_key || "#{self.class.tenant_association_name}_id"
          assoc_fk = associated_class.reflect_on_association(associated_class.tenant_association_name)&.foreign_key || "#{associated_class.tenant_association_name}_id"
          
          my_tenant_id = send(my_fk)
          assoc_tenant_id = associated_record.send(assoc_fk)
          
          if my_tenant_id && assoc_tenant_id && my_tenant_id != assoc_tenant_id
            errors.add(assoc.name, "belongs to a different tenant")
          end
        end
      end
    rescue => e
      # Safe fallback for uninitialized associations during setup
    end
  end

  module RelationExtension
    def update_all(updates)
      check_tenant_scope!
      super
    end

    def delete_all
      check_tenant_scope!
      super
    end

    private

    def check_tenant_scope!
      return unless klass.respond_to?(:tenant_association_name)
      return unless Tenantify.tenant_scoped?

      if Tenantify.current_tenant.nil?
        raise TenantMismatchError, "Bulk operation attempted on tenant-scoped model #{klass.name} without an active tenant context"
      end

      fk = klass.reflect_on_association(klass.tenant_association_name)&.foreign_key || "#{klass.tenant_association_name}_id"
      
      where_hash = where_values_hash
      unless where_hash[fk.to_s] == Tenantify.current_tenant.id || where_hash[fk.to_sym] == Tenantify.current_tenant.id
        raise TenantMismatchError, "Bulk operation bypassed tenant scope for #{klass.name}. Use Tenantify.without_tenant if this was intentional."
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Relation.prepend(Tenantify::RelationExtension)
end
