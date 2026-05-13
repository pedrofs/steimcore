# frozen_string_literal: true

class OrganizationsController < InertiaController
  with_title "Organização"
  with_breadcrumb label: "Organização", path: -> { organization_path }

  def show
    render inertia: "organizations/show", props: {
      organization: organization_props,
      members: members_props,
      pending_invitations: pending_invitations_props
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

    def members_props
      current_organization.users.order(:created_at).map do |user|
        {
          id: user.id,
          email: user.email_address,
          joined_at: user.created_at.iso8601,
          is_current_user: user.id == Current.user.id
        }
      end
    end

    def pending_invitations_props
      current_organization
        .invitations
        .where(accepted_at: nil)
        .includes(:invited_by)
        .order(created_at: :desc)
        .map do |invitation|
          {
            id: invitation.id,
            email: invitation.email_address,
            invited_by_email: invitation.invited_by.email_address,
            invited_at: invitation.created_at.iso8601,
            expired: invitation.expired?
          }
        end
    end
end
