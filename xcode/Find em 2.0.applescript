-- Find 'Em 2.0.applescript
-- Find 'Em 2.0

--  Created by Robert Pufky on 10/7/07.
--  Copyright 2007. All rights reserved.
-- --------------------------------------------------------------------
-- Global Private Variables
-- --------------------------------------------------------------------
property Song_Drawer_Opened : false
property Debug_Mode : false
property Song_Queue_Count : 0
property Table_Queue : ""
property Table_Queue_Data : ""
property Table_Drawer : ""
property Table_Drawer_Data : ""
property Lyrics_Tab : ""
property Lyrics_Text_View : ""
property cache_location : "/tmp/"
property Findem_Python : ""
-- --------------------------------------------------------------------

-- --------------------------------------------------------------------
-- Occurs whenever a new tab is selected
-- --------------------------------------------------------------------
on selected tab view item theObject tab view item tabViewItem
	if the name of tabViewItem is "SongsQueue" then
		tell drawer "SongDrawer" of window "MainWindow" to close drawer
		if Debug_Mode then log "selected tab view item: Song queue selected, closing side drawer"
	end if
	if the name of tabViewItem is "LyricsTab" then
		__PopulateSongDrawer()
		tell drawer "SongDrawer" of window "MainWindow" to open drawer on right edge
	end if
end selected tab view item

-- --------------------------------------------------------------------
-- Called when an object is 'opened'
-- --------------------------------------------------------------------
on opened theObject
	if the name of theObject is "SongDrawer" then
		set title of button "DrawerButton" of tab view item "LyricsTab" of tab view "Tabs" of window "MainWindow" to "Hide Songs"
		set Song_Drawer_Opened to true
		if Debug_Mode then log "opened: " & Song_Drawer_Opened
	end if
end opened

-- --------------------------------------------------------------------
-- Called when an object is 'closed'
-- --------------------------------------------------------------------
on closed theObject
	if the name of theObject is "SongDrawer" then
		set title of button "DrawerButton" of tab view item "LyricsTab" of tab view "Tabs" of window "MainWindow" to "Show Songs"
		set Song_Drawer_Opened to false
		if Debug_Mode then log "closed: " & Song_Drawer_Opened
	end if
end closed

-- --------------------------------------------------------------------
-- Determines what button was clicked, and launches appropriate action
-- --------------------------------------------------------------------
on clicked theObject
	if Debug_Mode then log theObject
	if the name of theObject is "RemoveQueueSong" then
		if Debug_Mode then log "clicked: Remove a song"
		__RemoveQueueSong(false)
	else if the name of theObject is "DrawerButton" then
		if Debug_Mode then log "clicked: Song Drawer button clicked"
		if Song_Drawer_Opened then
			if Debug_Mode then log "clicked: Song drawer opened, closing..."
			tell drawer "SongDrawer" of window "MainWindow" to close drawer
		else
			if Debug_Mode then log "clicked: Song drawer closed, opening..."
			tell drawer "SongDrawer" of window "MainWindow" to open drawer on right edge
		end if
	else if the name of theObject is "RemoveSong" then
		if Debug_Mode then log "clicked: Removing a song from songlist"
		__RemoveDrawerSong()
	else if the name of theObject is "ApplyLyrics" then
		if Debug_Mode then log "clicked: applying lyrics to all songs"
		__ApplyLyrics()
	else if the name of theObject is "FormatLyrics" then
		if Debug_Mode then log "clicked: formatting current lyrics"
		__FormatLyrics()
	else if the name of theObject is "FetchLyrics" then
		if Debug_Mode then log "clicked: fetching lyrics from web"
		__FetchLyrics()
	else if the name of theObject is "GetCurrentSelection" then
		if Debug_Mode then log "clicked: Getting current itunes selection"
		__GetCurrentSelection()
	else if the name of theObject is "SkipButton" then
		if Debug_Mode then log "clicked: Skipping current song"
		__RemoveQueueSong(true)
		__PopulateSongDrawer()
	else if the name of theObject is "GoogleSearch" then
		if Debug_Mode then log "clicked: Search on google for lyrics"
		__GoogleSearch()
	else if the name of theObject is "SongsTable" then
		if Debug_Mode then log "clicked: SongsTable"
		if (count of data row of Table_Drawer_Data) > 0 then
			if Debug_Mode then log "clicked: Displaying new lyrics"
			__DisplayLyrics()
		end if
	end if
end clicked

-- --------------------------------------------------------------------
-- Called when an drop occurs in the object
-- --------------------------------------------------------------------
on drop theObject drag info dragInfo
	if the name of theObject is "Lyrics" then
		if "string" is in types of pasteboard of dragInfo then
			set string value of theObject to contents of pasteboard of dragInfo
		end if
	end if
end drop

-- --------------------------------------------------------------------
-- Called when an event happens on an object
-- --------------------------------------------------------------------
on awake from nib theObject
	log "awake from nib: " & name of theObject
	if the name of theObject is "Lyrics" then
		tell theObject to register drag types {"string"}
	end if
end awake from nib

-- --------------------------------------------------------------------
-- When a selection is picked from the menu
-- --------------------------------------------------------------------
on choose menu item theObject
	if the name of theObject is "MenuQuit" then
		quit
	end if
end choose menu item

-- --------------------------------------------------------------------
-- Gets the current selection from iTunes, add it to Queue
-- --------------------------------------------------------------------
on __GetCurrentSelection()
	tell application "Finder"
		if (get name of every process) does not contain "iTunes" then tell application "iTunes" to launch
	end tell
	
	-- we should probably do some version / error checking here...	
	using terms from application "iTunes"
		set song_queue to {}
		tell application "iTunes" to set all_songs to (get selection)
		repeat with i from 1 to the count of the all_songs
			set current_song to item i of all_songs
			tell application "iTunes" to set the end of the song_queue to {name, album artist, artist, database ID} of current_song
		end repeat
		if Debug_Mode then
			log "__GetCurrentSelection: "
			log song_queue
		end if
	end using terms from
	
	-- Set table view, also update pointer to data source as this can change
	set content of Table_Queue to song_queue
	set Table_Queue_Data to the data source of Table_Queue
	if Debug_Mode then log "__GetCurrentSelection: Set up table Queue Data pointer"
	set Song_Queue_Count to the (count data rows of Table_Queue_Data)
	if Debug_Mode then log "__GetCurrentSelection: Song queue count:" & Song_Queue_Count
end __GetCurrentSelection

-- --------------------------------------------------------------------
-- Removes a selected song from the queue
-- skip - true if we are 'skipping' and not deleting a highlight
-- --------------------------------------------------------------------
on __RemoveQueueSong(skip)
	if Song_Queue_Count > 0 then
		if Debug_Mode then log "__RemoveQueueSong: Table actual queue count: " & (count data rows of Table_Queue_Data)
		-- we have to specify a row if we are accessing it remotely (it's considered unselected when not shown)
		if skip then
			set delete_row to data row 1 of Table_Queue_Data
		else
			set delete_row to selected data row of Table_Queue
		end if
		if Debug_Mode then
			log "__RemoveQueueSong: Song queue count: " & Song_Queue_Count
			log delete_row
		end if
		delete delete_row
		set Song_Queue_Count to Song_Queue_Count - 1
		update
		if Debug_Mode then
			log "__RemoveQueueSong: Done removing a song."
			log "__RemoveQueueSong: Song queue count: " & Song_Queue_Count
		end if
	end if
end __RemoveQueueSong

-- --------------------------------------------------------------------
-- Removes a selected song from the song drawer
-- --------------------------------------------------------------------
on __RemoveDrawerSong()
	if (count data rows of Table_Drawer_Data) > 0 then
		set delete_row to selected data row of Table_Drawer
		if Debug_Mode then
			log "__RemoveDrawerSong: Remove Drawer Song: "
			log delete_row
		end if
		delete delete_row
		update
		if Debug_Mode then log "__RemoveDrawerSong: Done removing a song."
		
		-- if there are no songs left after deletion, move on
		if (count data rows of Table_Drawer_Data) = 0 then
			if Debug_Mode then log "__RemoveDrawerSong: There are more queue items, loading..."
			__RemoveQueueSong(true)
			if Song_Queue_Count > 0 then __PopulateSongDrawer()
		else
			if Debug_Mode then log "__RemoveDrawerSong: There are no more queue items, refreshing blank"
			__DisplayLyrics()
		end if
	end if
end __RemoveDrawerSong

-- --------------------------------------------------------------------
-- Populations the SongsTable with new song information
-- --------------------------------------------------------------------
on __PopulateSongDrawer()
	if Song_Queue_Count > 0 then
		-- grab the current track in the queue, we don't adjust artist here, as we use it for a key to lookup items in itunes
		set current_song_name to the contents of data cell "SQSong" of data row 1 of Table_Queue_Data
		set current_song_artist to the contents of data cell "SQAlbumArtist" of data row 1 of Table_Queue_Data
		if Debug_Mode then log "__PopulateSongDrawer: Current song: " & current_song_name & " - " & current_song_artist
		set song_drawer_queue to {}
		
		-- grab all the tracks in itunes that match
		using terms from application "iTunes"
			tell application "iTunes" to set song_tracks to tracks of library playlist 1 whose name is current_song_name and album artist is current_song_artist
			repeat with i from 1 to the number of song_tracks
				set temp_track_list to {}
				set current_track to item i of song_tracks
				-- populate the side drawer from those matches
				tell application "iTunes" to set temp_track_list to {database ID, album} of current_track
				
				if item 2 of temp_track_list = "" then
					if Debug_Mode then log "__PopulateSongDrawer: Album is NOT set; setting to (No Album)"
					set the end of the song_drawer_queue to {item 1 of temp_track_list, "(No Album)"}
				else
					if Debug_Mode then log "__PopulateSongDrawer: Album is set"
					set the end of the song_drawer_queue to {item 1 of temp_track_list, item 2 of temp_track_list}
				end if
			end repeat
		end using terms from
		if Debug_Mode then
			log "__PopulateSongDrawer: Current Song List"
			log song_drawer_queue
		end if
		
		-- set content of drawer, and set default selection to first row
		set content of Table_Drawer to song_drawer_queue
		set Table_Drawer_Data to the data source of Table_Drawer
		set selected row of Table_Drawer to 1
		if Debug_Mode then log "__PopulateSongDrawer: Set selected row to 1"
		update
		if Debug_Mode then log "__PopulateSongDrawer: updated screen"
		__DisplayLyrics()
	else
		set the contents of text view "Lyrics" of scroll view "Lyrics" of tab view item "LyricsTab" of tab view "Tabs" of window "MainWindow" to ""
		set the contents of text field "SongTitle" of tab view item "LyricsTab" of tab view "Tabs" of window "MainWindow" to "Artist:Album - Song"
		set content of Table_Drawer to {}
	end if
end __PopulateSongDrawer

-- --------------------------------------------------------------------
-- Grabs the specified songs lyrics from the Table_Drawer_Data index (Song list)
-- --------------------------------------------------------------------
on __DisplayLyrics()
	if (count data rows of Table_Drawer_Data) > 0 then
		set song_database_id to the contents of data cell "SDDatabaseID" of selected data row of Table_Drawer
		if Debug_Mode then log "__DisplayLyrics: song database id: " & song_database_id
		
		using terms from application "iTunes"
			tell application "iTunes" to set song_lyrics to lyrics of some track of library playlist 1 whose database ID is song_database_id
		end using terms from
		if Debug_Mode then log "__DisplayLyrics: " & song_lyrics
		
		set the contents of text view "Lyrics" of scroll view "Lyrics" of tab view item "LyricsTab" of tab view "Tabs" of window "MainWindow" to song_lyrics
		
		set current_album_artist to the contents of data cell "SQAlbumArtist" of data row 1 of Table_Queue_Data
		if current_album_artist = "" or current_album_artist = "Various Artists" then
			if Debug_Mode then log "__DisplayLyrics: Album Artist is blank, or using 'Various Artists'.  Using Artist field"
			set current_album_artist to item 1 of ___Split(the contents of data cell "SQArtist" of data row 1 of Table_Queue_Data, ",")
		end if
		
		set the contents of text field "SongTitle" of tab view item "LyricsTab" of tab view "Tabs" of window "MainWindow" to Â
			current_album_artist & " - " & Â
			the contents of data cell "SQSong" of data row 1 of Table_Queue_Data
		update
	else
		set the contents of text view "Lyrics" of scroll view "Lyrics" of tab view item "LyricsTab" of tab view "Tabs" of window "MainWindow" to ""
		set the contents of text field "SongTitle" of tab view item "LyricsTab" of tab view "Tabs" of window "MainWindow" to "Artist:Album - Song"
	end if
end __DisplayLyrics

-- --------------------------------------------------------------------
-- Formats the lyrics using the python script
-- --------------------------------------------------------------------
on __FormatLyrics()
	if (count data rows of Table_Drawer_Data) > 0 then
		set database_id to the contents of data cell "SDDatabaseID" of selected data row of Table_Drawer
		set old_lyrics to the contents of text view "Lyrics" of scroll view "Lyrics" of tab view item "LyricsTab" of tab view "Tabs" of window "MainWindow"
		if Debug_Mode then log "__FormatLyrics: databaseid " & database_id
		
		set file_handle to cache_location & database_id & ".lyrics"
		set file_pipe to open for access POSIX file file_handle with write permission
		set eof of file_pipe to 0
		write old_lyrics to file_pipe as Çclass utf8È
		close access POSIX file file_handle
		
		set the contents of text view "Lyrics" of scroll view "Lyrics" of tab view item "LyricsTab" of tab view "Tabs" of window "MainWindow" to Â
			do shell script (quoted form of Findem_Python) & " -d " & database_id & " -f" as Çclass utf8È
		
		update
	end if
end __FormatLyrics

-- --------------------------------------------------------------------
-- Fetches lyrics from python script (using cache first, then web)
-- --------------------------------------------------------------------
on __FetchLyrics()
	if (count data rows of Table_Drawer_Data) > 0 then
		set database_id to the contents of data cell "SDDatabaseID" of selected data row of Table_Drawer
		
		set song_artist to the contents of data cell "SQAlbumArtist" of data row 1 of Table_Queue_Data
		if song_artist = "" or song_artist = "Various Artists" then
			if Debug_Mode then log "__FetchLyrics: Album Artist is blank, or using 'Various Artists'.  Using Artist field"
			set song_artist to item 1 of ___Split(the contents of data cell "SQArtist" of data row 1 of Table_Queue_Data, ",")
		end if
		
		set song_name to the contents of data cell "SQSong" of data row 1 of Table_Queue_Data
		if Debug_Mode then log "__FetchLyrics: database id " & database_id & " artist: " & song_artist & "|song: " & song_name
		
		set file_handle to cache_location & database_id & ".lyrics.control"
		set file_pipe to open for access POSIX file file_handle with write permission
		set eof file_pipe to 0
		write song_artist & "
" & song_name to file_pipe as Çclass utf8È
		close access POSIX file file_handle
		
		set the contents of text view "Lyrics" of scroll view "Lyrics" of tab view item "LyricsTab" of tab view "Tabs" of window "MainWindow" to Â
			do shell script (quoted form of Findem_Python) & " -d " & database_id as Çclass utf8È
		
		update
	end if
end __FetchLyrics

-- --------------------------------------------------------------------
-- Applies current lyrics in text field to all songs in Drawer
-- --------------------------------------------------------------------
on __ApplyLyrics()
	if (count data rows of Table_Drawer_Data) > 0 then
		set new_lyrics to the contents of text view "Lyrics" of scroll view "Lyrics" of tab view item "LyricsTab" of tab view "Tabs" of window "MainWindow"
		set database_ids to the contents of data cell "SDDatabaseID" of data rows of Table_Drawer_Data
		if Debug_Mode then
			log "__ApplyLyrics: database id's to modify:"
			log database_ids
		end if
		
		set minimum value of progress indicator "ProgressBar" of Lyrics_Tab to 1
		set maximum value of progress indicator "ProgressBar" of Lyrics_Tab to count of database_ids
		set content of progress indicator "ProgressBar" of Lyrics_Tab to 0
		set visible of progress indicator "ProgressBar" of Lyrics_Tab to true
		start progress indicator "ProgressBar" of Lyrics_Tab
		
		if Debug_Mode then
			log "__ApplyLyrics: setup progress bar"
			log "__ApplyLyrics: database count: " & (count of database_ids)
		end if
		
		repeat with i from 1 to the count of database_ids
			if Debug_Mode then log "__ApplyLyrics: Applying to database id: " & item i of database_ids
			using terms from application "iTunes"
				tell application "iTunes" to set (lyrics of some track of library playlist 1 whose database ID is item i of database_ids) to new_lyrics
			end using terms from
			set content of progress indicator "ProgressBar" of Lyrics_Tab to i
			delay 0.1
		end repeat
		
		set visible of progress indicator "ProgressBar" of Lyrics_Tab to false
		stop progress indicator "ProgressBar" of Lyrics_Tab
	end if
end __ApplyLyrics

-- --------------------------------------------------------------------
-- Runs when the program is first launched
-- --------------------------------------------------------------------
on will open theObject
	if the name of theObject is "MainWindow" then
		-- associate our table views with shorter names for clarity
		set Table_Queue to table view "SQueue" of scroll view "SQueue" of tab view item "SongsQueue" of tab view "Tabs" of window "MainWindow"
		if Debug_Mode then log "will open: Set up table Queue pointer"
		set Table_Drawer to table view "SongsTable" of scroll view "SongsTable" of drawer "SongDrawer" of window "MainWindow"
		if Debug_Mode then log "will open: Set up table Drawer pointer"
		set Lyrics_Tab to tab view item "LyricsTab" of tab view "Tabs" of window "MainWindow"
		if Debug_Mode then log "will open: Set up lyrics tab pointer"
		set Findem_Python to (POSIX path of (path to me) as string) & "Contents/Resources/findem2.0.py"
		if Debug_Mode then log "will open: Set up pointer to python engine: " & Findem_Python
	end if
end will open

-- --------------------------------------------------------------------
-- When a Google Search is picked
-- --------------------------------------------------------------------
on __GoogleSearch()
	if (count data rows of Table_Drawer_Data) > 0 then
		set song_artist to the contents of data cell "SQAlbumArtist" of data row 1 of Table_Queue_Data
		if song_artist = "" or song_artist = "Various Artists" then
			if Debug_Mode then log "__GoogleSearch: Album Artist is blank, or using 'Various Artists'.  Using Artist field"
			set song_artist to item 1 of ___Split(the contents of data cell "SQArtist" of data row 1 of Table_Queue_Data, ",")
		end if
		
		set song_name to the contents of data cell "SQSong" of data row 1 of Table_Queue_Data
		if Debug_Mode then log "__GoogleSearch: artist: " & song_artist & " | song: " & song_name
		set encoded_text to ___EncodeText(song_artist & " " & song_name & " lyrics", true, true)
		tell application "Finder"
			open location "http://www.google.com/search?hl=en&q=" & encoded_text & "&btnG=Google+Search"
		end tell
	end if
end __GoogleSearch

-- --------------------------------------------------------------------
-- Encodes a given string to a URL safe format
-- --------------------------------------------------------------------
on ___EncodeText(this_text, encode_URL_A, encode_URL_B)
	set the standard_characters to Â
		"abcdefghijklmnopqrstuvwxyz0123456789"
	set the URL_A_chars to "$+!'/?;&@=#%><{}[]\"~`^\\|*"
	set the URL_B_chars to ".-_:"
	set the acceptable_characters to the standard_characters
	if encode_URL_A is false then Â
		set the acceptable_characters to Â
			the acceptable_characters & the URL_A_chars
	if encode_URL_B is false then Â
		set the acceptable_characters to Â
			the acceptable_characters & the URL_B_chars
	set the encoded_text to ""
	repeat with this_char in this_text
		if this_char is in the acceptable_characters then
			set the encoded_text to Â
				(the encoded_text & this_char)
		else
			set the encoded_text to Â
				(the encoded_text & ___EncodeChar(this_char)) as string
		end if
	end repeat
	return the encoded_text
end ___EncodeText

-- --------------------------------------------------------------------
-- Converts a given character to the html escaped equivalent
-- --------------------------------------------------------------------
on ___EncodeChar(this_char)
	set this_char to this_char as string
	set the ASCII_num to (the ASCII number this_char)
	set the hex_list to Â
		{"0", "1", "2", "3", "4", "5", "6", "7", "8", Â
			"9", "A", "B", "C", "D", "E", "F"}
	set x to item ((ASCII_num div 16) + 1) of the hex_list
	set y to item ((ASCII_num mod 16) + 1) of the hex_list
	return ("%" & x & y) as string
end ___EncodeChar

-- --------------------------------------------------------------------
-- Returns a list of strings, split on the delimeter
-- --------------------------------------------------------------------
on ___Split(mystring, delim)
	set original_delim to AppleScript's text item delimiters
	set AppleScript's text item delimiters to delim
	set split_text to text items of mystring
	set AppleScript's text item delimiters to original_delim
	
	return split_text
end ___Split

on mouse up theObject event theEvent
	(*Add your script here.*)
end mouse up

on will close theObject
	(*Add your script here.*)
end will close

on drag exited theObject drag info dragInfo
	(*Add your script here.*)
end drag exited

on drag theObject drag info dragInfo
	(*Add your script here.*)
end drag

on conclude drop theObject drag info dragInfo
	(*Add your script here.*)
end conclude drop

on prepare drop theObject drag info dragInfo
	(*Add your script here.*)
end prepare drop

on drag updated theObject drag info dragInfo
	(*Add your script here.*)
end drag updated

on drag entered theObject drag info dragInfo
	(*Add your script here.*)
end drag entered