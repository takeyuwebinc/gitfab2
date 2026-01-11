class UsagesController < ApplicationController
  include SpamKeywordDetection

  before_action :load_owner
  before_action :load_project
  before_action :build_usage, only: [:new, :create]
  before_action :load_usage, only: [:edit, :update, :destroy]
  before_action :update_contribution, only: [:create, :update]

  authorize_resource class: Card::Usage.name

  def new
  end

  def edit
  end

  def create
    if detect_spam_keyword(contents: [@usage.title, @usage.description], content_type: "Usage")
      render json: { success: false, error: spam_keyword_rejection_message }, status: :unprocessable_entity
      return
    end

    if @usage.save
      @project.touch
      render :create
    else
      render json: { success: false }, status: 400
    end
  end

  def update
    @usage.assign_attributes(usage_params)

    if detect_spam_keyword(contents: [@usage.title, @usage.description], content_type: "Usage")
      render json: { success: false, error: spam_keyword_rejection_message }, status: :unprocessable_entity
      return
    end

    if @usage.save
      @project.touch
      render :update
    else
      render json: { success: false }, status: 400
    end
  end

  def destroy
    if @usage.destroy
      @project.touch
      render json: { success: true }
    else
      render json: { success: false }, status: 400
    end
  end

  private

    def load_owner
      owner_id = params[:owner_name] || params[:user_id] || params[:group_id]
      @owner = Owner.find(owner_id)
    end

    def load_project
      @project = @owner.projects.active.friendly.find(params[:project_id])
    end

    def load_usage
      @usage = @project.usages.find(params[:id])
    end

    def build_usage
      @usage = @project.usages.build usage_params
    end

    def usage_params
      if params[:usage]
        params.require(:usage).permit Card::Usage.updatable_columns
      end
    end

    def update_contribution
      return unless current_user
      @usage.contributions.each do |contribution|
        if contribution.contributor_id == current_user.id
          contribution.updated_at = DateTime.now.in_time_zone
          return
        end
      end
      contribution = @usage.contributions.new
      contribution.contributor_id = current_user.id
      contribution.created_at = DateTime.now.in_time_zone
      contribution.updated_at = DateTime.now.in_time_zone
    end
end
