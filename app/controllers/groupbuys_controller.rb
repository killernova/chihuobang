#encoding:utf-8
require 'rest-client'
require 'digest/sha1'
class GroupbuysController < ApplicationController
  before_action :validate_user!, only: [:new, :edit, :update, :create, :destroy]
  def index
    @groupbuys = Groupbuy.where(locale: session[:locale]).includes(:user).order(created_at: :desc)
  end

  def show
    @parent = @groupbuy  = Groupbuy.find(params[:id])
    if @parent.pic_url.present?
      @title_pic = @groupbuy.pic_url.split(',').reject{|x| x.blank?}[0]
      @content_pic = @groupbuy.pic_url.split(',').reject{|x| x.blank?}[1..-1]
    else
      @title_pic = @parent.photos.first.try(:image)
      @content_pic = @parent.photos[1..-1]
    end
    
    @active = @groupbuy.comments.count > 10 ? true : false
    @participant = @parent.participants.new
    @comment = @parent.comments.new
    @participants = @groupbuy.participants.includes(:user)
    more = 10
    @comments = @groupbuy.comments.includes(:user)[0...more]

    #微信share接口配置
    @title = "#{@groupbuy.user.nickname}推荐您加入团购：#{@groupbuy.title}"
    @img_url = 'http://www.trade-v.com:5000' + @title_pic
    @desc = @groupbuy.body
    supplier = Supplier.where(:id => 78).first
    @timestamp = Time.now.to_i
    @appId = supplier.weixin_appid
    @noncestr = random_str 16
    @jsapilist = ['onMenuShareTimeline', 'onMenuShareAppMessage', 'onMenuShareQQ', 'onMenuShareWeibo', 'onMenuShareQZone']
    @jsapi_ticket = get_jsapi_ticket
    post_params = {
      :noncestr => @noncestr,
      :jsapi_ticket => @jsapi_ticket,
      :timestamp => @timestamp,
      :url => request.url.gsub("localhost:5000", "www.trade-v.com")
    }
    @sign = create_sign_for_js post_params
    @a = [post_params, request.url.gsub("trade", "vshop.trade-v.com")]


    if current_user
      @user_addresses = current_user.user_addresses
      if  @user_addresses.size == 0
        return redirect_to new_user_address_path(groupbuy_id: params[:groupbuy_id], from: 'new_participant')
      elsif  @user_addresses.where(default: 1).present?
        @user_addresses =  @user_addresses.where(default: 1)
      else
        @user_addresses =  @user_addresses.first
      end
    end

   #@amount = Foodie::Participant.where

   if signed_in? 
     @plus_menu = [{name: '<i class="fa  fa-comment"></i>'.html_safe+' '+t(:new_comment), path: new_groupbuy_comment_path(@groupbuy)},
      {name: '<i class="fa fa-user-plus"></i>'.html_safe+' '+t(:buy), path: new_groupbuy_participant_path(@groupbuy)}
    ]
    if @participants.where(:user_id => current_user.id).size>0
      @again = '再次'     
    else
      @again = '立即'
    end
  end

end

def new
 @groupbuy = Groupbuy.new
 session[:pic_file] = nil
 @photo = Photo.new
end

def create
  @groupbuy = Groupbuy.new(groupbuy_params)
  @groupbuy.pic_url = ''
  @groupbuy.user = current_user
  @groupbuy.locale = session[:locale]

    # uploaded_io = params[:file]
    # if !uploaded_io.blank?
    #   extension = uploaded_io.original_filename.split('.')
    #   filename = "#{Time.now.strftime('%Y%m%d%H%M%S')}.#{extension[-1]}"
    #   filepath = "#{PIC_PATH}/groupbuys/#{filename}"
    #   File.open(filepath, 'wb') do |file|
    #     file.write(uploaded_io.read)
    #   end
    #       # groupbuy_params.merge!(:pic_url=>"/groupbuys/#{filename}")
    #       @groupbuy.pic_url = "/groupbuys/#{filename}"
    # end
    if @groupbuy.save
      photo_ids = params[:photo_ids].split(',')
      Photo.where(id: photo_ids).update_all(groupbuy_id: @groupbuy.id)

      post_url = "http://www.trade-v.com/send_group_message_api"
      # openids = User.plunk(:weixin_openid)
      openids = "oVxC9uBr12HbdFrW1V0zA3uEWG8c"
      msgtype = "text"
      content = "吃货帮刚刚发布了一个新团购：#{@groupbuy.title}, 赶紧来看看哦～"
      data_hash = {
        openids: openids,
        content: content,
        data: {msgtype: msgtype}
      }
      data_json = data_hash.to_json
      res_data_json = RestClient.post post_url, data_hash


      redirect_to groupbuy_url(@groupbuy), notice: '团购发布成功!'
    else
      render :new
    end
  end

  def edit
    @groupbuy = Groupbuy.find(params[:id])
    @pic = @groupbuy.pic_url.split(',').reject{|x| x.blank?}
  end

  def update
    if params[:from] == 'admin_groupbuy_list'
      if params[:recommend].blank?
        return render :text => 'failed'
      end
      num = params[:recommend].to_i
      if Groupbuy.find(params[:id]).update(recommend: num)
        Rails.logger.info 'true'
        return render :text => 'success'
      end
    end

    if params[:from] == 'admin_edit_title'
      if params[:title].blank?
        return render :text => 'failed'
      end
      if Groupbuy.find(params[:id]).update(title: params[:title])
        Rails.logger.info 'true'
        return render :text => 'success'
      end
    end




    @groupbuy = Groupbuy.find(params[:id])
    if params[:images]
      params[:images].each do |image|
        @groupbuy.photos.update(image: image)
      end
    end
    if @groupbuy.update(groupbuy_params) && @groupbuy.update(pic_url: params[:pic_url])
      redirect_to groupbuy_url(@groupbuy), notice: '团购修改成功'
    else
      render :edit
    end
  end

  def upload
    uploaded_io = params[:file]
    
    if !uploaded_io.blank?
      extension = uploaded_io.original_filename.split('.')
      filename = "#{Time.now.strftime('%Y%m%d%H%M%S%L')}.#{extension[-1]}"
      filepath = "#{PIC_PATH}/groupbuys/#{filename}"
      File.open(filepath, 'wb') do |file|
        file.write(uploaded_io.read)
      end
      @pic_urls = ',/groupbuys/' + filename
      respond_to do |format|
        format.js
      end
    end
  end

  def destroy_pic
    @groupbuy = Groupbuy.find(params[:id])
    url = params[:url]
    pic_url = @groupbuy.pic_url
    new_pic_url = pic_url.gsub(url, '')
    pic_name = url.split('/').last
    if @groupbuy.update(pic_url: new_pic_url)
      `cd "#{Rails.root}"/public/groupbuys`
      `rm "#{pic_name}"`
      return render text: new_pic_url
    else
      return render text: 'failed'
    end
  end

  def destroy
    @groupbuy = Groupbuy.find(params[:id])
    @groupbuy.destroy
    respond_to do |format|
      format.js
      format.html {redirect_to groupbuys_path}
    end
  end

  def more_comments
    elements = []
    parent = params[:parent]
    start = params[:start].to_i
    over = params[:over].to_i
    comments = parent.capitalize.constantize.includes(:comments, :user).find(params[:id]).comments.includes(:user)[start...over]
    comments.each do |comment|
      elements << "<div class='row small-collapse'><div  class='columns small-12 comment'>" << comment.body.html_safe if comment.body << view_context.comment_info(comment) << "</div></div><hr />"
    end
    elements = elements.join
    return render text: elements
  end

  private
  def set_groupbuy
    @groupbuy = Groupbuy.find(params[:id])
  end

  def groupbuy_params
    params.require(:groupbuy).permit(:title, :body,:end_time,:start_time,:groupbuy_type, :goods_maximal, :goods_minimal, :market_price,
      :pic_url,:limited_people,:goods_big_than,:goods_small_than,:name,:mobile,:goods_unit,:price,:pic_url)
  end

  def to_label_xml hash
    params_str = ''
    hash.each do |key, value|
      params_str += "<#{key}>" + "<![CDATA[#{value}]]>" + "</#{key}>"
    end
    params_xml = '<xml>' + params_str + '</xml>'
  end

  def random_str str_length
    arr = ('0'..'9').to_a + ('a'..'z').to_a
    nonce_str = ''
    str_length.times do
      nonce_str += arr[rand(36)]
    end
    nonce_str
  end

  def create_sign hash
    key = Supplier.where(:name => '贸威').first.partner_key
    stringA = hash.select{|key, value|value.present?}.sort.map do |arr|
     arr.map(&:to_s).join('=')
   end
   stringA = stringA.join("&")
   string_sing_temp = stringA + "&key=#{key}"
   sign = (Digest::MD5.hexdigest string_sing_temp).upcase
 end

 def create_sign_for_js hash
  key = Supplier.where(:name => '贸威').first.partner_key
  stringA = hash.select { |key, value| value.present? }.sort.map do |arr|
    arr.map(&:to_s).join('=')
  end
  stringA = stringA.join("&")
  sign = (Digest::SHA1.hexdigest stringA)
end



def get_jsapi_ticket
    supplier = Supplier.where(:id => 78).first
    return supplier.jsapi_ticket if supplier.expires_at.to_i > Time.now.to_i && supplier.jsapi_ticket.present?
    access_token = get_jsapi_access_token
    get_url = 'https://api.weixin.qq.com/cgi-bin/ticket/getticket'
    res_data_json = RestClient.get get_url, {:params => {:access_token => access_token, :type => 'jsapi'}}
    res_data_hash = ActiveSupport::JSON.decode res_data_json
    if res_data_hash['errmsg'] == 'ok'
      jsapi_ticket = res_data_hash['ticket']
      supplier.update_attributes(:jsapi_ticket => jsapi_ticket)
    end
    jsapi_ticket
end

def get_jsapi_access_token
  supplier = Supplier.where(:id => 78).first
  return supplier.access_token if supplier.expires_at.to_i > Time.now.to_i
  get_url = 'https://api.weixin.qq.com/cgi-bin/token'
  res_data_json = RestClient.get get_url, {:params => {:appid => supplier.weixin_appid, :grant_type => 'client_credential', :secret => supplier.weixin_appsecret}}
  res_data_hash = ActiveSupport::JSON.decode res_data_json
  access_token = res_data_hash["access_token"]
  expires_at = Time.now.to_i + res_data_hash['expires_in'].to_i
  supplier.update_attributes(:access_token => access_token, :expires_at => expires_at)
  access_token
end
end
