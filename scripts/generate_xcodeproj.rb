#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "pathname"
require "xcodeproj"

ROOT = Pathname.new(__dir__).parent.expand_path
IOS_ROOT = ROOT.join("ios", "GreenhouseHelper")
PROJECT_PATH = IOS_ROOT.join("GreenhouseHelper.xcodeproj")
TARGET_NAME = "GreenhouseHelper"

FileUtils.rm_rf(PROJECT_PATH) if PROJECT_PATH.exist?

project = Xcodeproj::Project.new(PROJECT_PATH.to_s)
project.root_object.attributes["LastSwiftUpdateCheck"] = "1610"
project.root_object.attributes["LastUpgradeCheck"] = "1610"

target = project.new_target(:application, TARGET_NAME, :ios, "17.0")
target.product_name = "Greenhouse Helper"

target.build_configurations.each do |config|
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.bloomlogic.greenhousehelper"
  config.build_settings["INFOPLIST_FILE"] = "Supporting/Info.plist"
  config.build_settings["SWIFT_VERSION"] = "5.0"
  config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "17.0"
  config.build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
  config.build_settings["ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME"] = "AccentColor"
  config.build_settings["CODE_SIGN_STYLE"] = "Automatic"
  config.build_settings["GENERATE_INFOPLIST_FILE"] = "NO"
end

main_group = project.main_group
ios_group = main_group

%w[App Models Services ViewModels Views Supporting Assets.xcassets].each do |folder|
  ios_group.find_subpath(folder, true)
end

Dir[IOS_ROOT.join("{App,Models,Services,ViewModels,Views}/**/*.swift")].sort.each do |file|
  rel = Pathname.new(file).relative_path_from(IOS_ROOT).to_s
  ref = ios_group.new_file(rel)
  target.add_file_references([ref])
end

[
  IOS_ROOT.join("Assets.xcassets").to_s
].each do |resource|
  rel = Pathname.new(resource).relative_path_from(IOS_ROOT).to_s
  ref = ios_group.new_file(rel)
  target.resources_build_phase.add_file_reference(ref, true)
end

project.save
puts "Generated #{PROJECT_PATH}"
