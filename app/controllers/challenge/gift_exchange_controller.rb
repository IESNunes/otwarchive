class Challenge::GiftExchangeController < ChallengesController
  
  before_filter :users_only
  before_filter :load_collection
  before_filter :load_challenge, :except => [:new, :create]
  before_filter :collection_owners_only, :only => [:new, :create, :edit, :update, :destroy]
  before_filter :set_time_zone, :only => [:create, :edit, :update]

  # ACTIONS

  # we use this to make the times get set in the moderator's specified timezone
  def set_time_zone
    if params[:gift_exchange] && params[:gift_exchange][:time_zone]
      Time.zone = params[:gift_exchange][:time_zone]
    elsif @challenge && @challenge.time_zone
      Time.zone = @challenge.time_zone
    end
  end

  def show
  end

  def new
    if (@collection.challenge)
      flash[:notice] = t('gift_exchange.already_challenge', :default => "There is already a challenge set up for this collection.")
      redirect_to edit_collection_gift_exchange_path(@collection)
    else
      @challenge = GiftExchange.new
    end
  end

  def edit
  end

  def create
    @tag_set_initialized = false
    @challenge = GiftExchange.new(params[:gift_exchange])
    if @challenge.save
      @collection.challenge = @challenge
      @collection.save
      flash[:notice] = 'Challenge was successfully created.'
      if @tag_set_initialized
        # we initialized the tag set
        flash[:notice] += ' Please look over the initial tag set.'
        render :action => :edit
      else
        redirect_to @collection
      end
    else
      render :action => :new
    end
  end

  def update
    @tag_set_initialized = false
    if @challenge.update_attributes(params[:gift_exchange])
      flash[:notice] = 'Challenge was successfully updated.'
      
      # expire the cache on the signup form
      expire_fragment(:controller => 'challenge_signups', :action => 'new')
      
      if @initialized
        # we were asked to initialize the tag set
        flash[:notice] += ' Please look over the initial tag set.'
        render :action => :edit
      else
        redirect_to @collection
      end
    else
      render :action => :edit
    end
  end

  def destroy
    @challenge.destroy
    flash[:notice] = 'Challenge settings were deleted.'
    redirect_to @collection
  end

end
