#!/usr/bin/env ruby

#Source reference: https://stackoverflow.com/a/53208376
#Reference author: Shuangquan Wei
#Reference author profile: https://stackoverflow.com/users/5445143/shuangquan-wei

require 'xcodeproj'

def is_resource(file)
    extname= file[/\.[^\.]+$/]
    if extname == '.bundle' || extname == '.xcassets' || extname == '.xib' || extname == '.html' || extname == '.strings' then
        return true
    else
        return false
    end
end

def align_files(project, target, group)

    if File.exist?(group.real_path) 

        Dir.foreach(group.real_path) do |entry|
            filePath = File.join(group.real_path, entry)
            if filePath.to_s.end_with?(".DS_Store", ".xcconfig") then
                puts "Ignoring configuration file " + filePath
            elsif filePath.to_s.end_with?(".lproj") then
                if @variant_group.nil?
                    @variant_group = group.new_variant_group("Localizable.strings");
                end
                string_file = File.join(filePath, "Localizable.strings")
                puts "Adding strings file " + string_file
                fileReference = @variant_group.new_reference(string_file)
                target.add_resources([fileReference])
            elsif is_resource(entry) then
                puts "Adding resource " + filePath
                fileReference = group.new_reference(filePath)
                target.add_resources([fileReference])
            elsif !File.directory?(filePath) then
                fileReference = group.new_reference(filePath)
                if filePath.to_s.end_with?(".m", ".mm", ".cpp", ".swift") then
                    puts "Adding source " + filePath
                    target.add_file_references([fileReference])

                elsif filePath.to_s.end_with?(".pch") then

                elsif filePath.to_s.end_with?("Info.plist") && entry == "Info.plist" then

                elsif filePath.to_s.end_with?(".h") then
                    # target.headers_build_phase.add_file_reference(fileReference)
                elsif filePath.to_s.end_with?(".framework") || filePath.to_s.end_with?(".xcframework") || filePath.to_s.end_with?(".a") then
                    puts "Adding framework " + filePath
                    target.frameworks_build_phases.add_file_reference(fileReference)
                elsif
                    puts "Adding resource " + filePath
                    target.add_resources([fileReference])
                end
            
            elsif File.directory?(filePath) && entry != '.' && entry != '..' then
                puts "Creating subgroup " + entry 
                subGroup = group.find_subpath(entry, true)
                subGroup.set_source_tree(group.source_tree)
                subGroup.set_path(File.join(group.real_path, entry))
                align_files(project, target, subGroup)

            end
        end
    end
end

target_name = ARGV[0].to_s
project_path = './' + target_name + '/' + target_name + '.xcodeproj'
project = Xcodeproj::Project.open(project_path)
group = project[target_name]

project.targets.each do |target|
	if target.name == target_name
        puts 'Removing resources'
		target.source_build_phase.files.to_a.map do |file|
			file.remove_from_project
		end
        puts 'Removing sources'
		target.resources_build_phase.files.to_a.map do |file|
			file.remove_from_project
		end
        puts 'Cleaning group'
		group.clear
        puts 'Aligning files'
		align_files(project, target, group)
	end
end

project.save