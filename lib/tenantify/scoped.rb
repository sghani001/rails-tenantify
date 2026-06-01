# frozen_string_literal: true

module Tenantify
  module Scoped
    extend ActiveSupport::Concern

    class_methods do
      def belongs_to_tenant(association_name, **options)
        class_attribute :tenant_association_name, instance_accessor: false
        self.tenant_association_name = association_name

        belongs_to association_name, **options

        default_scope lambda {
          if Tenantify.tenant_scoped? && Tenantify.current_tenant
            fk = reflect_on_association(association_name)&.foreign_key || "#{association_name}_id"
            where(fk => Tenantify.current_tenant.id)
          else
            all
          end
        }

        before_validation :set_tenant_automatically, on: :create
        validate :validate_tenant_not_changed, on: :update
        validate :validate_cross_tenant_associations
      end

      def tenant_scoped?
        tenant_association_name.present?
      end
    end

    private

    def set_tenant_automatically
      association_name = self.class.tenant_association_name
      return unless association_name

      fk = self.class.reflect_on_association(association_name)&.foreign_key || "#{association_name}_id"
      return unless send(fk).nil? && Tenantify.current_tenant

      send("#{association_name}=", Tenantify.current_tenant)
    end

    def validate_tenant_not_changed
      association_name = self.class.tenant_association_name
      return unless association_name

      fk = self.class.reflect_on_association(association_name)&.foreign_key || "#{association_name}_id"
      return unless send("#{fk}_changed?") && !send("#{fk}_was").nil?

      errors.add(fk, "cannot be changed after creation")
    end

    def validate_cross_tenant_associations
      association_name = self.class.tenant_association_name
      return unless association_name

      self.class.reflect_on_all_associations(:belongs_to).each do |assoc|
        next if assoc.name == association_name

        associated_class = assoc.klass
        next unless associated_class.respond_to?(:tenant_scoped?) && associated_class.tenant_scoped?

        associated_record = send(assoc.name)
        next if associated_record.nil?

        my_fk = self.class.reflect_on_association(association_name)&.foreign_key || "#{association_name}_id"
        assoc_fk = associated_class.reflect_on_association(associated_class.tenant_association_name)&.foreign_key ||
                   "#{associated_class.tenant_association_name}_id"

        my_tenant_id = send(my_fk)
        assoc_tenant_id = associated_record.send(assoc_fk)

        if my_tenant_id && assoc_tenant_id && my_tenant_id != assoc_tenant_id
          errors.add(assoc.name, "belongs to a different tenant")
        end
      end
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

    def destroy_all
      check_tenant_scope!
      super
    end

    private

    def check_tenant_scope!
      return unless klass.respond_to?(:tenant_scoped?) && klass.tenant_scoped?
      return unless Tenantify.tenant_scoped?

      if Tenantify.current_tenant.nil?
        raise TenantMismatchError,
              "Bulk operation attempted on tenant-scoped model #{klass.name} without an active tenant context"
      end

      fk = klass.reflect_on_association(klass.tenant_association_name)&.foreign_key ||
           "#{klass.tenant_association_name}_id"

      where_hash = where_values_hash
      tenant_id = Tenantify.current_tenant.id
      scoped_to_tenant = where_hash[fk.to_s] == tenant_id || where_hash[fk.to_sym] == tenant_id

      return if scoped_to_tenant

      raise TenantMismatchError,
            "Bulk operation bypassed tenant scope for #{klass.name}. Use Tenantify.without_tenant if this was intentional."
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Relation.prepend(Tenantify::RelationExtension)
end
