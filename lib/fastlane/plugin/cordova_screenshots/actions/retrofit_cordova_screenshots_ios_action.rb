require 'xcodeproj'

module Fastlane
  module Actions
    class RetrofitCordovaScreenshotsIosAction < Action
      def self.run(params)
        UI.message("Retrofitting iOS UI test from '#{CordovaScreenshots::CORDOVA_SCREENSHOTS_IOS_CONFIG_PATH}' into Cordova iOS Xcode project.")

        (!params.nil? && !params[:ios_xcode_path].nil?) || UI.user_error!("Mandatory parameter :ios_xcode_path not specified")

        #
        # Params
        #
        xcode_project_path = params[:ios_xcode_path]
        team_id = params[:team_id]
        bundle_id = params[:bundle_id]
        target_os = params[:min_target_ios]
        swift_version = params[:swift_version]

        File.exist?(xcode_project_path) || UI.user_error!("Xcode project '#{xcode_project_path}' does not exist!")

        #
        # Find all preconfigured UI Unit Tests
        #
        schemes = Dir.glob("#{CordovaScreenshots::CORDOVA_SCREENSHOTS_IOS_CONFIG_PATH}/*/").reject do |d|
          d =~ /^\.{1,2}$/ # excludes . and ..
        end
        UI.message("Found schemes: #{schemes}")

        # TODO: Error message if no schemes were found, refer to `init_cordova_screenshots_ios`

        #
        # Process each scheme
        #
        schemes.each do |scheme_path|
          UI.message("Processing scheme: #{scheme_path}...")
          generate_xcode_unit_test(scheme_path, xcode_project_path, team_id, bundle_id, target_os, swift_version)
        end

        UI.success("Done. You can now run `fastlane snapshot` to take screenshots.")
      end

      def self.generate_xcode_unit_test(config_folder, xcode_project_path, team_id, bundle_id, target_os, swift_version)
        #
        # Names and Folders
        #
        scheme_name = File.basename(config_folder)
        xcode_folder = File.dirname(xcode_project_path)
        project_name = File.basename(xcode_project_path, ".xcodeproj")

        UI.message("Setting up '#{scheme_name}' as UI Unit Test folder and Scheme in '#{xcode_folder}' for Xcode project '#{project_name}'")

        #
        # Xcode Project
        #
        proj = Xcodeproj::Project.open(xcode_project_path) || UI.user_error!("Unable to open Xcode project '#{xcode_project_path}'")

        UI.message("Xcode project is version '#{proj.root_object.compatibility_version}' compatible")

        #
        # Clean Xcode project
        #
        proj = clean_xcode_project(proj, scheme_name)

        #
        # Add new Unit Tests to Xcode projects
        #
        proj = add_unit_tests_to_xcode_project(proj, scheme_name, config_folder, project_name, target_os, team_id, bundle_id, xcode_project_path, swift_version)

        #
        # Success
        #
        UI.success("Completed retrofit of '#{scheme_name}' into generated Xcode Project '#{project_name}'.")
      end

      def self.clean_xcode_project(proj, scheme_name)
        #
        # Find existing Target
        #
        target = nil
        proj.targets.each do |t|
          next unless t.name == scheme_name
          UI.important("Found existing Target '#{t.name}' and removed it.")
          target = t
          break
        end

        #
        # Find existing code group
        #
        test_group = nil
        proj.groups.each do |g|
          next unless g.name == scheme_name
          g.clear
          test_group = g
          UI.important("Found existing Code Group '#{g.name}' and removed it.")
          break
        end

        #
        # Remove existing target and group
        #
        target.nil? || target.remove_from_project
        test_group.nil? || test_group.remove_from_project

        #
        # Find existing products groups and remove
        #
        product_ref_name = scheme_name + '.xctest'
        proj.products_group.files.each do |product_ref|
          if product_ref.path == product_ref_name
            UI.important("Found existing Product Group '#{product_ref.path}' and removed it.")
            product_ref.remove_from_project
          end
        end

        proj
      end

      def self.add_unit_tests_to_xcode_project(proj, scheme_name, config_folder, project_name, target_os, team_id, bundle_id, xcode_project_path, swift_version)
        #
        # Create new test group
        #
        UI.message("Creating UI Test Group '#{scheme_name}' for snapshots testing")
        test_group = proj.new_group(scheme_name.to_s, File.absolute_path(config_folder), '<absolute>')

        #
        # Find main target
        #
        UI.message("Finding Main Target (of the project)...")
        main_target = nil
        proj.root_object.targets.each do |t|
          if t.name == project_name
            UI.message("Found main target as '#{t.name}'")
            main_target = t
          end
        end

        main_target || UI.user_error!("Unable to locate Main Target for app in '#{project_name}'")

        #
        # Create new target
        #
        target = proj.new_target(:ui_test_bundle, scheme_name, :ios, target_os, proj.products_group, :swift)

        #
        # "Create" product and put into target
        #
        product_ref_name = scheme_name + '.xctest'
        product_ref = proj.products_group.find_file_by_path(product_ref_name)
        target.product_reference = product_ref

        #
        # Add main_target as dependency of target
        #
        UI.message("Adding Main Target Dependency to new Target: '#{main_target}'")
        target.add_dependency(main_target)

        # We need to save here for some reason... xcodeproj!?
        proj.save

        #
        # Add files (fastlane configured UI Unit Tests) into target (via test group)
        #
        UI.message("Adding Pre-Configured UI Unit Tests (*.plist and *.swift) to Test Group '#{scheme_name}'...")

        files = []
        Dir["#{config_folder}*.plist", "#{config_folder}*.swift"].each do |file| # config_folder ends with / already
          UI.message("Adding UI Test Source '#{file}'")
          files << test_group.new_reference(File.absolute_path(file), '<absolute>')
        end
        # TODO: Manually add `fastlane/SnapshotHelper.swift` (or actual location)
        target.add_file_references(files)

        #
        # Configure project and target metadata
        #
        UI.message("Configuring Project Metadata")

        target_config = {
          CreatedOnToolsVersion: "8.2",
          DevelopmentTeam: team_id,
          ProvisioningStyle: "Automatic",
          TestTargetID: main_target.uuid
        }
        if proj.root_object.attributes['TargetAttributes']
          proj.root_object.attributes['TargetAttributes'].store(target.uuid, target_config)
        elsif
          proj.root_object.attributes.store('TargetAttributes', { target.uuid => target_config })
        end

        target.build_configuration_list.set_setting('INFOPLIST_FILE', File.absolute_path("#{config_folder}/Info.plist"))
        target.build_configuration_list.set_setting('SWIFT_VERSION', swift_version)
        target.build_configuration_list.set_setting('PRODUCT_NAME', "$(TARGET_NAME)")
        target.build_configuration_list.set_setting('TEST_TARGET_NAME', project_name)
        target.build_configuration_list.set_setting('PRODUCT_BUNDLE_IDENTIFIER', "#{bundle_id}.#{scheme_name}")
        target.build_configuration_list.set_setting('CODE_SIGN_IDENTITY[sdk=iphoneos*]', "iPhone Developer")
        target.build_configuration_list.set_setting('LD_RUNPATH_SEARCH_PATHS', "$(inherited) @executable_path/Frameworks @loader_path/Frameworks")
        target.build_configuration_list.set_setting('DEVELOPMENT_TEAM', team_id)

        #
        # Create a shared scheme for the UI tests
        #
        UI.message("Generating Xcode Scheme '#{scheme_name}' to run UI Snapshot Tests")
        existing_scheme = Xcodeproj::XCScheme.shared_data_dir(xcode_project_path) + "/#{scheme_name}.xcscheme"
        scheme = File.exist?(existing_scheme) ? Xcodeproj::XCScheme.new(existing_scheme) : Xcodeproj::XCScheme.new

        #
        # Add target and main target to scheme
        #
        scheme.add_test_target(target)
        scheme.add_build_target(main_target)
        scheme.set_launch_target(main_target)

        #
        # Save scheme and project
        #
        scheme.save_as(xcode_project_path, scheme_name)
        proj.save

        proj
      end

      def self.description
        'Retrofit test into iOS Xcode project'
      end

      def self.authors
        ['Adrian Regan', 'Jan Piotrowski']
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        ''
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :ios_xcode_path,
                                       env_name: 'CORDOVA_SCREENSHOTS_IOS_XCODE_PATH',
                                       description: 'Path to Xcode project generated by Cordova/Ionic',
                                       default_value: Fastlane::Helper::CordovaScreenshotsHelper.find_default_ios_xcode_workspace,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :min_target_ios,
                                       env_name: 'CORDOVA_SCREENSHOTS_MIN_TARGET_IOS',
                                       description: 'Minimal iOS Version to target',
                                       default_value: CordovaScreenshots::CORDOVA_SCREENSHOTS_DEFAULT_IOS_VERSION,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :team_id,
                                       env_name: 'CORDOVA_SCREENSHOTS_TEAM_ID',
                                       description: 'Team ID in iTunes Connect or Apple Developer',
                                       default_value: CredentialsManager::AppfileConfig.try_fetch_value(:team_id),
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :bundle_id, # TODO?
                                       env_name: 'CORDOVA_SCREENSHOTS_BUNDLE_ID',
                                       description: 'The Bundle ID of the iOS App, eg: ie.littlevista.whateverapp',
                                       default_value: CredentialsManager::AppfileConfig.try_fetch_value(:package_name),
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :swift_version,
                                       env_name: 'CORDOVA_SCREENSHOTS_SWIFT_VERSION',
                                       description: 'Swift Version to target',
                                       default_value: CordovaScreenshots::CORDOVA_SCREENSHOTS_DEFAULT_SWIFT_VERSION,
                                       optional: false)

        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://github.com/fastlane/fastlane/blob/master/fastlane/docs/Platforms.md
        #
        # [:ios, :mac, :android].include?(platform)
        [:ios].include?(platform)
      end
    end
  end
end
