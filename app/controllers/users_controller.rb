#encoding:utf-8
class UsersController < ApplicationController
  before_action :select_user, only: [:show, :edit, :update, :destroy, :user_info, :my_orders]
  before_action only: [:edit, :update, :destroy, :my_orders] do
    validate_permission! select_user
  end

  def new   
    if !session[:openid].blank?
      user = User.where(weixin_openid: session[:openid])
      if user.present?
        login(user.first)
      end
    end
    @user = User.new
    @groups = Group.all
  end

  def create
    if user_params[:password].nil?
      user_params[:password] = user_params[:mobile]
      user_params[:username] = user_params[:mobile]
    end
    @user = User.new(user_params)
    @user.weixin_openid = session[:openid]
    @user.avatar = session[:avatar]    
    @user.nickname = session[:nickname]
    if params[:from] == 'share_from_foodie'
      @user.weixin_openid = params[:openid]
      @user.avatar = params[:avatar]    
      @user.nickname = params[:nickname]
      @user.group_id = params[:group_id]
    end

    if @user.save
      login(@user)
      if params[:return_url]
        return redirect_to URI.decode(params[:return_url])
      else
        return redirect_to root_url, notice: '注册成功!'
      end
    else
      render :new
    end
  end

  def show

    type = params[:type] || 'topic'

    case type 
    when 'topic'
      @user = User.includes(:topics).find_by_username(params[:id])
      if @user
        @data = @user.topics.includes(:forum)
      end
    when 'comment'
      @user = User.includes(:comments).find_by_username(params[:id])
      @data = @user.comments.includes(:topic)
      #@data = @user.comments.includes(:events)
    when 'event'
      @user = User.includes(:events).find_by_username(params[:id])
      @data = @user.events
    when 'groupbuy'
      @user = User.includes(:groupbuys).find_by_username(params[:id])
      @data = @user.groupbuys
    when 'participant'
      @user = User.includes(:participants).find_by_username(params[:id])
      @data = @user.participants.includes(:event)
    end
    if current_user == @user
      @group = Group.find_by_id(current_user.group_id)
      if @group
        @group_admin = User.find_by_id(@group.user_id)
      end
      if ['1', '2'].include? current_user.try(:role) 

        @groups = Group.where(user_id: current_user.id)
        if current_user.role == '1'
          @groups = Group.all
        end
      end
    end

    render layout: "profile2", locals: {page: type}
  end

  def user_info
    case @user.sex
    when '0'
      @sex = 'unknown'
    when '1'
      @sex = 'male'
    when '2'
      @sex = 'female'
    end
  end

  def my_orders
    @orders = Participant.includes(:groupbuy).where('user_id = ? AND groupbuy_id > ?', current_user.id, 0 ).order(created_at: :desc)
  end

  def edit
  end

  def update
    uploaded_io = params[:file]

    if !uploaded_io.blank?
      extension = uploaded_io.original_filename.split('.')
      filename = "#{Time.now.strftime('%Y%m%d%H%M%S')}.#{extension[-1]}"
     # filepath = "#{PIC_PATH}/teachResources/devices/#{filename}"
     filepath = "#{PIC_PATH}/avatars/#{filename}"
     File.open(filepath, 'wb') do |file|
      file.write(uploaded_io.read)
    end
    user_params.merge!(:avatar=>"/avatars/#{filename}")
  end

  update_params = user_params

  if update_params.has_key?(:password)
    update_params.delete([:password, :password_confirmation])
  end

  if @user.update(update_params)
    redirect_to profile_url(@user), notice: '个人信息修改成功'
  else
    render :edit, layout: "profile"
  end
end

def destroy
  logout
  @user.destroy
  redirect_to root_url
end

private

def user_params
  params.require(:user).permit!
end

def select_user
  @user = User.find_by_username(params[:id])
end
end
