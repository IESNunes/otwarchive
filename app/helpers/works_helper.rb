module WorksHelper

  # List of date, chapter and length info for the work show page
  def work_meta_list(work, chapter=nil)
    # if we're previewing, grab the unsaved date, else take the saved first chapter date
    published_date = (chapter && work.preview_mode) ? chapter.published_at : work.first_chapter.published_at
    list = [[t('works_helper.published', :default => "Published:"), localize(published_date)], [t('works_helper.words', :default => "Words:"), work.word_count], 
            [t('works_helper.chapters', :default => "Chapters:"), work.chapter_total_display]]

    if work.count_visible_comments > 0
      list.concat([[t('works_helper.work_comments', :default => 'Comments') + ':', work.count_visible_comments.to_s]])
    end
    if (bookmark_count = work.bookmarks.is_public.count) > 0
      list.concat([[t('works_helper.work_bookmarks', :default => 'Bookmarks') + ':', link_to(bookmark_count.to_s, work_bookmarks_path(work))]])
    end
    list.concat([[t('works_helper.hits', :default => "Hits:"), work.hits]]) if show_hit_count?(work)

    if work.chaptered? && work.revised_at
      prefix = work.is_wip ? "Updated:" : "Completed:"
      latest_date = (work.preview_mode && work.backdate) ? published_date : work.revised_at.to_date
      list.insert(1, [prefix, localize(latest_date)])
    end
    list = list.map {|list_item| content_tag(:dt, list_item.first) + content_tag(:dd, list_item.last.to_s)}.join.html_safe
    content_tag(:dl, list.to_s).html_safe
  end

  def show_hit_count?(work)
    return false if logged_in? && current_user.preference.try(:hide_all_hit_counts)
    author_wants_to_see_hits = is_author_of?(work) && !current_user.preference.try(:hide_private_hit_count)
    all_authors_want_public_hits = work.users.select {|u| u.preference.try(:hide_public_hit_count)}.empty?
    author_wants_to_see_hits || (!is_author_of?(work) && all_authors_want_public_hits)
  end

  def recipients_link(work)
    # join doesn't maintain html_safe, so mark the join safe
    work.gifts.map {|gift| link_to(h(gift.recipient), gift.pseud ? user_gifts_path(gift.pseud.user) : gifts_path(:recipient => gift.recipient_name))}.join(", ").html_safe
  end
  
  # select the default warning if this is a new work
  def check_warning(work, warning)
    if work.nil? || work.warning_strings.empty? 
      warning.name == ArchiveConfig.WARNING_DEFAULT_TAG_NAME 
    else
      work.warning_strings.include?(warning.name)
    end
  end
  
  # select default rating if this is a new work
  def rating_selected(work)
    work.nil? || work.rating_string.empty? ? ArchiveConfig.RATING_DEFAULT_TAG_NAME : work.rating_string
  end
  
  # Determines whether or not to expand the related work association fields when the work form loads
  def check_parent_box(work)
    !work.parents.blank? || 
    (params[:work] && !(work_parent_value(:url).blank? && work_parent_value(:title).blank? && work_parent_value(:author).blank?))
  end
  
  # Passes value of fields for related works back to form when an error occurs on posting
  def work_parent_value(field)
    if params[:work] && params[:work][:parent_attributes]
      params[:work][:parent_attributes][field]
    end
  end
  
  # Return true or false to determine whether the published at field should show on the work form
  def check_backdate_box(work, chapter)
    work.backdate || (chapter.created_at && chapter.created_at.to_date != chapter.published_at)
  end

  def language_link(work)
    if work.respond_to?(:language) && work.language
      link_to work.language.name, work.language
    else
      "N/A"
    end
  end
    
  def can_see_work(work, user)
    unless work.collections.empty?
      for collection in work.collections
        return true if collection.user_is_maintainer?(user)
      end
    end
    false
  end
  
  def marktoread_link(work)
    reading = Reading.find_by_work_id_and_user_id(work.id, current_user.id)
    if reading && reading.toread?
      link_to "Mark as read", marktoread_user_reading_path(current_user, reading, :work_id => work.id)
    elsif reading
      link_to "Mark to read later", marktoread_user_reading_path(current_user, reading, :work_id => work.id)
    else
      reading = Reading.create(:work_id => work.id, :user_id => current_user.id)
      reading.major_version_read, reading.minor_version_read = @work.major_version, @work.minor_version
      reading.save
      link_to "Mark to read later", marktoread_user_reading_path(current_user, reading, :work_id => work.id)
    end
  end
  
  # get a nicely formatted bit of text for pasting into other services
  # title (# words) by authors
  # Fandom:
  # Rating: 
  # Warnings:
  # etc
  def get_embed_link(work)
    title_link = link_to(content_tag(:strong, work.title), work_url(work)) + " (#{work.word_count} #{ts('words')})"
    profile_link = work.pseuds.map {|pseud| link_to(image_tag(root_url + "favicon.ico", :alt => "favicon") + " #{pseud.name}", user_profile_url(pseud.user))}.join(', ').html_safe
    fandom_text = ts("Fandom: ") + work.fandoms.map {|fandom| link_to fandom.name, tag_url(fandom)}.join(', ').html_safe
    rating_text = ts("Rating: ") + work.ratings.map {|rating| rating.name}.join(', ')
    category_text = ts("Category: ") + work.categories.map {|cat| cat.name}.join(', ')
    warning_text = ts("Warning: ") + work.warnings.map {|warning| warning_display_name(warning.name)}.join(', ')
    relationship_text = ts("Relationships: ") + work.relationships.map {|rel| rel.name}.join(', ')
    char_text = ts("Characters: ") + work.characters.map {|char| char.name}.join(', ')
    summary_text = work.summary.blank? ? "" : ts("Summary: ") + sanitize_field(work, :summary)
    
    # we deliberately don't html_safe this because we want it escaped
    [title_link + ts(" by ") + profile_link, fandom_text, rating_text, warning_text, relationship_text, char_text, summary_text].join("\n")
  end
  
  # convert a bookmark into a nicely formatted chunk of text
  def get_bookmark_embed_link(bookmark)
    if bookmark.bookmarkable.is_a?(Work)
      work_embed = get_embed_link(bookmark.bookmarkable)
      tags_text = ts("Bookmarker's Tags: ") + bookmark.tags.map {|tag| tag.name}.join(", ")
      bookmark_text = bookmark.notes.blank? ? "" : content_tag(:strong, ts("Bookmarker's Notes: ")) + raw(sanitize_field(bookmark, :notes))
      [work_embed, tags_text, bookmark_text].join("\n")
    end
  end
end
