class ReSettingsController < RedmineReController
  unloadable
  menu_item :re

  def configure
    initialize_artifact_order(@project.id)

     name = @project.name      
     name = "#{name} Project" if name.length < 3
     name = name[0..49]       if name.length > 50
     
    @project_artifact = ReArtifactProperties.where({
      :project_id => @project.id,
      :artifact_type => "Project"}
    ).first_or_create!({
      :created_by => User.current.id,
      :updated_by => User.current.id,
      :artifact_id => @project.id,     
      :description => @project.description,
      :name => name}
    )
    
    @plugin_description = ReSetting.get_plain("plugin_description", @project.id)

    if request.post?
      save_user_config
    elsif params[:firstload] == "1"
      flash.now[:notice] = t(:re_settings_have_to_save)
    end

    # checking all artifacts should be done every time for now
    # since we are still adding new stuff which otherwise does
    # not get configured appropriately
    # Anyway, it does not take much time and its done only in here
    @re_artifact_configs = {}
    @re_artifact_order.each do |artifact_type|
      configured_artifact = ReSetting.get_serialized(artifact_type, @project.id)
      if configured_artifact.nil?
        logger.debug("##### found an unconfigured artifact of type '" + artifact_type.to_s + "', creating an initial configuration")
        configured_artifact = {}
        configured_artifact['in_use'] = true
        configured_artifact['alias'] = artifact_type.gsub(/^re_/, '').humanize
        configured_artifact['color'] = artifact_type.to_s.classify.constantize::INITIAL_COLOR
        ReSetting.set_serialized(artifact_type, @project.id, configured_artifact)
      end
      @re_artifact_configs[artifact_type] = configured_artifact
    end

    @re_relation_configs = {}
    @re_relation_types = ReRelationtype.find_all_by_project_id(@project.id)
    logger.debug @re_relation_types.inspect
    @re_settings = {}
    @re_settings["visualization_size"] = ReSetting.get_plain("visualization_size", @project.id)
    @re_settings["visualization_size"] ||= 800

    @re_visualization_setting = {}
    @re_visualization_setting["deep"] = ReSetting.get_plain("visualization_deep", @project.id)
    issue = ReSetting.get_plain("issues", @project.id)
    if (issue == "yes" || issue == true)
        @re_visualization_setting["issue"] = true
    else
        @re_visualization_setting["issue"] = false
    end
  end

  def self.for(artifact_type, project_id)
    # returns the settings hash for the according artifact_type
    self.get_serialized(artifact_type, project_id)
  end
  
  def edit_artifact_type_description
    @artifact_type = params[:artifact_type]
    configured_artifact = ReSetting.get_serialized(@artifact_type, @project.id)
    @description = configured_artifact['description']
    @hide_default_description = configured_artifact['hide_default_description']
    # Needed to use the form for helper and fill the textfield properly
    if request.post?
      configured_artifact['description'] = params[:description] unless params[:description].nil? 
      if params[:hide_default_description].blank? 
        configured_artifact['hide_default_description'] = 0
      else 
        configured_artifact['hide_default_description'] = 1
      end 
      ReSetting.set_serialized(@artifact_type, @project.id, configured_artifact)
      flash.now[:notice] = l(:re_description_updated_successfully)
      @description = configured_artifact['description']
      @hide_default_description = configured_artifact['hide_default_description']
    end
  end

private

  def initialize_artifact_order(project_id)
    configured_artifact_types = Array.new
    
    # Get Serialized order array artifact types:
    # 
    # ["re_vision","re_workarea","re_processword","re_rationale","re_requirement","re_scenario",
    #"re_task","re_goal","re_section","re_use_case","re_user_profile"]
    #
    stored_settings = ReSetting.get_serialized("artifact_order", project_id)
    
    # Put it into the empty configured_artifact_types array
    configured_artifact_types.concat(stored_settings) if stored_settings

    all_artifact_types = ReSetting::ARTIFACT_TYPES
    all_artifact_types.delete_if { |v| configured_artifact_types.include? v }
    configured_artifact_types.concat(all_artifact_types)

    ReSetting.set_serialized("artifact_order", project_id, configured_artifact_types)
    logger.debug(configured_artifact_types.to_yaml)
    @re_artifact_order = configured_artifact_types
  end

  def save_user_config
    #store new settings and configurations
    new_settings = params[:re_settings]
    new_artifact_order = ActiveSupport::JSON.decode(params[:re_artifact_order])
    new_relation_order = ActiveSupport::JSON.decode(params[:re_relation_order])
    new_visualization = params[:re_visualization_settings]
    
    ReSetting.set_plain("relation_management_pane", @project.id, new_settings.has_key?("relation_management_pane").to_s)
    ReSetting.set_plain("visualization_size", @project.id, new_settings["visualization_size"])
    deep=new_visualization['deep'].to_i.to_s

    if(deep != new_visualization['deep'].to_s)
      deep = 4
    end

    ReSetting.set_plain("visualization_deep", @project.id, deep)
    ReSetting.set_plain("issues",@project.id, new_visualization['issue'])
    ReSetting.set_plain("plugin_description", @project.id, params["plugin_description"])
    @plugin_description = params["plugin_description"]

    ReSetting.set_serialized("artifact_order", @project.id, new_artifact_order)
    ReSetting.set_serialized("relation_order", @project.id, new_relation_order)

    new_artifact_configs = params[:re_artifact_configs]
    new_artifact_configs.each_pair do |k,v|
      # disabled checkboxes do not send a key/value pair
      v['in_use'] = v.has_key? 'in_use'
      v['printable'] = v.has_key? 'printable'
      logger.debug('storing:' + k + ' ' + @project.id.to_s + ' ' + v.to_yaml)
      ReSetting.set_serialized(k, @project.id, v)
    end

    new_relation_configs = params[:re_relation_configs]
    new_relation_configs.each_pair do |k, v|
      r = ReRelationtype.find_or_create_by_id(v['id'])
      logger.debug "before: #{r.inspect}"
      unless r.is_system_relation
        r.in_use = v.has_key? 'in_use'
        r.is_directed = v.has_key? 'is_directed'
      end
      r.alias_name = v[:alias_name]
      r.color = v[:color]
      r.project_id = @project.id
      
      logger.debug "after: #{r.inspect}"
      #r.save
    end

    @re_artifact_order = ReSetting.get_serialized("artifact_order", @project.id)
    ReSetting.set_serialized("unconfirmed", @project.id, false)
      
    
    flash[:notice] = t(:re_configs_saved)
    
    redirect_to :controller => "requirements", :action => "index", :project_id => @project.id  

  end
  
end
