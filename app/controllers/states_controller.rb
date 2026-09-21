class StatesController < ApplicationController
  include SpamKeywordDetection
  include ReadonlyModeRestriction

  before_action :load_owner
  before_action :load_project
  before_action :build_state, only: [:new, :create]
  before_action :load_state, only: [:edit, :show, :update, :destroy]
  before_action :update_contribution, only: [:create, :update]
  before_action :restrict_readonly_mode, only: %i[create update destroy to_annotation]
  after_action :update_project, only: [:create, :update, :destroy]

  authorize_resource class: Card::State.name

  def new
  end

  def edit
  end

  def show
    render :show, formats: :json
  end

  def create
    if detect_spam_keyword(contents: [@state.title, @state.description], content_type: "State")
      render json: { success: false, error: spam_keyword_rejection_message }, status: :unprocessable_entity
      return
    end

    if @state.save
      render :create
    else
      render json: { success: false }, status: 400
    end
  end

  def update
    attributes, annotation_arrangement = split_annotation_arrangement(state_params)
    @state.annotations.verify_arrangement!(annotation_arrangement) if annotation_arrangement
    @state.assign_attributes(attributes)

    if detect_spam_keyword(contents: [@state.title, @state.description], content_type: "State")
      render json: { success: false, error: spam_keyword_rejection_message }, status: :unprocessable_entity
      return
    end

    if save_state(annotation_arrangement)
      render :update
    else
      render json: { success: false }, status: 400
    end
  rescue Card::InvalidArrangement
    render json: { success: false }, status: 400
  end

  def destroy
    if @state.destroy
      render json: { success: true }
    else
      render json: { success: false }, status: 400
    end
  end

  def to_annotation
    state = @project.states.find(params[:state_id])
    if can?(:manage, state)
      parent_state = @project.states.find(params[:dst_state_id])
      annotation = state.to_annotation!(parent_state)
      render json: {'$oid' => annotation.id}
    else
      render json: { success: false }, status: 400
    end
  rescue Card::State::InvalidConversionTarget
    render json: {
      success: false,
      error: "Cannot convert to the selected state. Please reload the page and try again."
    }, status: :unprocessable_entity
  end

  private

    def load_owner
      owner_id = params[:owner_name] || params[:user_id] || params[:group_id]
      owner_id.downcase!
      @owner = Owner.find(owner_id)
    end

    def load_project
      @project = @owner.projects.active.friendly.find(params[:project_id])
    end

    def load_state
      @state ||= @project.states.find(params[:id])
    end

    def build_state
      @state = @project.states.build(state_params)
    end

    def state_params
      (params[:state] || ActionController::Parameters.new).permit Card::State.updatable_columns
    end

    # annotations_attributes のうち position を持つ組を、Annotation の並べ替えの依頼として取り出す。
    # position を nested attributes で 1 件ずつ保存すると acts_as_list のコールバックが並びを崩すため、
    # 並べ替えは Card.rearrange! に任せ、残りの属性だけを State に代入する。
    def split_annotation_arrangement(attributes)
      entries = attributes[:annotations_attributes]
      return [attributes, nil] if entries.blank?

      entries = entries.values unless entries.is_a?(Array)
      # 組が Hash でない形（index をキーにしない単一の Hash など）は、そのまま並べ替えの依頼として
      # 検証させ、不正な依頼として拒否する。
      return [attributes, entries] unless entries.all? { |entry| entry.respond_to?(:key?) }

      arrangement = entries.select { |entry| entry.key?(:position) }.map { |entry| entry.slice(:id, :position) }
      [attributes.merge(annotations_attributes: entries.map { |entry| entry.except(:position) }), arrangement.presence]
    end

    def save_state(annotation_arrangement)
      @state.transaction do
        next false unless @state.save

        @state.annotations.rearrange!(annotation_arrangement) if annotation_arrangement
        true
      end
    end

    def update_contribution
      return unless current_user
      @state.contributions.each do |contribution|
        if contribution.contributor_id == current_user.id
          contribution.updated_at = DateTime.now.in_time_zone
          return
        end
      end
      contribution = @state.contributions.new
      contribution.contributor_id = current_user.id
      contribution.created_at = DateTime.now.in_time_zone
      contribution.updated_at = DateTime.now.in_time_zone
    end

    def update_project
      return unless @_response.response_code == 200
      @project.touch

      users = @project.notifiable_users current_user
      url = project_path(@project.owner, @project)
      body = "#{current_user.name} updated the recipe of #{@project.title}."
      @project.notify users, current_user, url, body if users.length > 0
    end
end
