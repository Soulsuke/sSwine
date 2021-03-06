require "fileutils"
require "pathname"
require "#{Pathname.new( $0 ).realpath.dirname}/lib/ham.rb"
require "#{Pathname.new( $0 ).realpath.dirname}/lib/oink.rb"

=begin
Sswine stands for "Sswine: split wine".  
This class is designed to handle Hams located in $HOME/.sswine. Each Ham must
be composed of:  
config.yaml:: Ham configuration file.  
wine_env:: Folder containing the wine bottle.  
Additionally, the following folders can also be present:  
icons:: Folder containing the Ham-specific icons.  
custom_wine:: Folder containing a Ham-specific version of wine to be used.  
=end

class Sswine
  @main_dir  # Main Sswine directory, located in $HOME/.sswine.
  @hams      # Each Ham is a sub-directory of @main_dir.
  @invisible # An invisible Sswine is one with no Hams.
  @logs      # Logs modality, either on, off or gui.

  # Our logger:
  include Oink

  # An invisible Sswine is one with no Hams.
  attr_reader :invisible

  # Constructor. To work properly, the following should be provided:
  # :logs => on/off/gui, modality to use for logging.
  def initialize options = { :logs => :off }
    @main_dir = Pathname.new "#{ENV["HOME"]}/.sswine"
    @hams = Array.new
    @innvisible = false
    @logs = options[:logs]
    oink_initialize

    # If the main folder does not exist, create it.
    unless @main_dir.directory? then
      if @main_dir.exist? then
        @main_dir.delete
      end

      @main_dir.mkpath

    # If it does, let's process the Hams!
    else
      # In alphabetical order.
      @main_dir.children.sort.each do |entry|
        pork = Ham.new :path => entry, :logs => @logs

        # Add any entry in @logs_gui of every Ham:
        logs_gui_append pork

        # No error message is printed here, because Ham's constructor already
        # does so.
        if pork.edible then
          @hams.push pork
        end
      end
    end

    # Is it an invisible Ham?
    if 0 == @hams.size then
      @invisible = true
    end
  end

  # Creates a menu folder for Sswine, and adds to it an entry for each valid
  # one of each Ham.
  public
  def writeMenuEntries
    # This is to make a decent log:
    created = Hash.new

    # Deleting this folder and creating one with the same name confuses some
    # DEs' menu triggers, apparently. So... We gotta ensure the directory 
    # exists, then remove every file it contains.
    desktop_files_folder = Pathname.new "#{ENV["HOME"]}/.local/share/" +
                                        "applications/sswine"

    if desktop_files_folder.exist? then
      desktop_files_folder.each_child do |entry|
        FileUtils.rm_r entry
      end

    else
      desktop_files_folder.mkpath
    end

    # Ensure the folder file exists:
    folder_file = Pathname.new "#{ENV["HOME"]}/.local/share/" +
                               "desktop-directories/sswine.directory"
    folder_file.dirname.mkpath

    # Write the folder file:
    File.open folder_file, "w" do |f|
      f.puts "[Desktop Entry]"
      f.puts "Icon=wine"
      f.puts "Name=Sswine"
      f.puts "Type=Directory"
      f.puts "Version=1.0"
    end

    # Ensure the menu file exists:
    menu_file = Pathname.new "#{ENV["HOME"]}/.config/menus/" +
                             "applications-merged/sswine.menu"
    menu_file.dirname.mkpath

    # GTK3 GUI .desktop file:
    gui_desktop_entry = Pathname.new "#{desktop_files_folder.realpath}/" +
                                     "SswineGTK3GUI.desktop"

    # If GTK3 library is available, go on:
    begin
      require "gtk3"

    # If it is not, avoid creating such entry:
    rescue LoadError
      gui_desktop_entry = nil
    end

    unless gui_desktop_entry.nil? then
      File.open gui_desktop_entry, "w" do |f|
        f.puts "[Desktop Entry]"
        f.puts "Categories=Games"
        f.puts "Comment=Sswine: split wine"
        f.puts "Encoding=UTF-8"
        f.puts "Exec=#{Pathname.new( $0 ).realpath} -g"
        f.puts "Icon=wine"
        f.puts "Name=Sswine"
        f.puts "Terminal=false"
        f.puts "Type=Application"
        f.puts ""
      end
    end

    # Write the first part of the menu file:
    File.open menu_file, "w" do |f|
      f.puts "<Menu>"
      f.puts "  <Name>Applications</Name>"
      f.puts "  <Menu>"
      f.puts "    <AppDir>#{desktop_files_folder.realpath}</AppDir>"
      f.puts "    <Name>Sswine</Name>"
      f.puts "    <Directory>#{folder_file.basename}</Directory>"
      f.puts "    <Include>"

      # If the gui's desktop file is present, then add it first:
      unless gui_desktop_entry.nil? then
        f.puts "      <Filename>#{gui_desktop_entry.basename}</Filename>"
      end
    end

    # Now, process each Ham...
    @hams.each do |ham|
      # Note down the name of this Ham:
      created[ham.folder.basename] = Array.new

      # For each entry it contains...
      ham.getDesktopEntries.each do |key, entry|
        # Write the relative.desktop file:
        File.open "#{desktop_files_folder.realpath}/#{key}", "w" do |f|
          f.puts entry

          # Add an empty line at the end:
          f.puts ""
        end

        # Add it to Sswine's menu file:
        File.open menu_file, "a" do |f|
          f.puts "      <Filename>#{key}</Filename>"
        end

        # Note down what this Ham has generated:
        created[ham.folder.basename].push key
      end
    end

    # Write the last part of the menu file:
    File.open menu_file, "a" do |f|
      f.puts "    </Include>"
      f.puts "  </Menu>"
      f.puts "</Menu>"
    end

    # Special message in case there are no valid Hams:
    if created.empty? and gui_desktop_entry.nil? then
      oink "No Hams found, no menu entries have been added."

    else
      # Header:
      oink "Created entries in #{@colors[:blue]}" +
           "#{desktop_files_folder.realpath}#{@colors[:default]} for:"

      # If the GUI entry has been created, print it first:
      unless gui_desktop_entry.nil? then
        oink " > #{@colors[:cyan]}Sswine" +
             "#{@colors[:default]}",
             "    #{gui_desktop_entry.basename}"
      end

      created.each do |key, entries|
        # Show the Ham's name:
        oink " > #{@colors[:cyan]}#{key}#{@colors[:default]}"

        # Show what this Ham has generated:
        entries.each do |entry|
          oink "    #{entry}"
        end
      end
    end
  end

  # Terminates every Ham (alive or not).
  public
  def killAllHams options = {}
    # This is to override @logs when we want to:
    if options.key? :logs  then
      @logs = options[:logs]
    end

    # Only has a meaning if there are any Hams:
    unless @invisible then
      @hams.each do |h|
        h.killHam
      end

    else
      oink "No Hams found. Nothing to do."
    end
  end

  # Attempts to update every Ham.
  public
  def updateAllHams options = {}
    # This is to override @logs when we want to:
    if options.key? :logs  then
      @logs = options[:logs]
    end

    # Only has a meaning if there are any Hams:
    unless @invisible then
      @hams.each do |h|
        h.updateHam
      end

    else
      oink "No Hams found. Nothing to do."
    end
  end

  # Prints a list of all the available hams, then makes the user chose one.
  # A shell will be opened in such Ham's directory, with the WINEPREFIX
  # varialbe correctly set. The shell to use will be the user's default one.
  public
  def openShell options = {}
    # This is to override @logs when we want to:
    if options.key? :logs  then
      @logs = options[:logs]
    end

    # This will store the user input:
    choice = -1

    if @invisible then
      oink "No Hams found. Nothing to do."

    else
      # It has to be user-interactive!
      while true do
        # Print the selection menu:
        puts "Edible hams:"
        @hams.each_with_index do |h, idx|
          puts "[#{idx + 1}] - #{h.folder.basename}"
        end
        print "Choose one: "

        # Get the user input:
        choice = STDIN.gets.chomp.to_i - 1

        # Input error check:
        if @hams[choice].nil? or 0 > choice then
          puts "Invalid value. Please, try again."
          puts ""

        # Valid choice: out of the loop!
        else
          break
        end
      end

      # Open the desired shell!
      @hams[choice].openShell
    end
  end

end

