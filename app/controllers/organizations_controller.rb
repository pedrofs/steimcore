# frozen_string_literal: true

class OrganizationsController < InertiaController
  with_title "Organização"
  with_breadcrumb label: "Organização", path: -> { organization_path }

  def show
    render inertia: "organizations/show", props: {
      organization: organization_props
    }
  end

  def edit
    render inertia: "organizations/edit", props: {
      organization: organization_props
    }
  end

  def update
    if current_organization.update(organization_params)
      redirect_to organization_path, notice: "Equipamentos atualizados."
    else
      redirect_to edit_organization_path,
                  inertia: { errors: current_organization.errors.to_hash(true) }
    end
  end

  private
    def organization_params
      params.require(:organization).permit(:equipment_list_md)
    end

    def organization_props
      {
        id: current_organization.id,
        name: current_organization.name,
        equipment_list_md: current_organization.equipment_list_md
      }
    end
end
