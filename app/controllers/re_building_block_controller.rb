class ReBuildingBlockController < RedmineReController
  unloadable
  menu_item :re

  def new
    redirect_to :action => 'edit', :project_id => params[:project_id], :artifact_type => params[:artifact_type]
  end
  
  def update_config_form
    @project = Project.find(params[:project_id])
    @artifact_type = params[:artifact_type]
    # just looks for the rjs-Template with the same name
  end
  
  def edit
   @re_building_block = ReBuildingBlock.find_by_id(params[:id]) || ReBuildingBlock.new
   @project = Project.find(params[:project_id])
   @artifact_type = params[:artifact_type]
   
   if request.post?
      params[:re_building_block][:artifact_type] = params[:artifact_type]
      params[:re_building_block][:type] = params[:type]
      # Test if @re_builing_block is a new object
      @re_building_block = params[:type].constantize.new if @re_building_block.artifact_type.nil?
      @re_building_block.attributes = params[:re_building_block]
      flash[:notice] = t(:re_bb_saved) if save_ok = @re_building_block.save
      # Calling the strategies for handling additional work after normal saving
      @re_building_block.additional_work_after_save_strategy.call(params[:options], @re_building_block)
      redirect_to :action => 'edit', :id => @re_building_block.id, :building_block => @re_building_block, :building_block_type => params[:type].underscore, :artifact_type => params[:artifact_type], :project_id => @project.id and return if save_ok
   end
  end

end
