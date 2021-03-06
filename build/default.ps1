properties {
	$pwd = Split-Path $psake.build_script_file	
	$build_directory  = "$pwd\output\condep-node"
	$configuration = "Release"
	$releaseNotes = ""
    $nunitPath = "$pwd\..\src\packages\NUnit.ConsoleRunner.3.4.1\tools"
	$nuget = "$pwd\..\tools\nuget.exe"
}
 
include .\..\tools\psake_ext.ps1

Framework '4.6x64'

function GetNugetAssemblyVersion($assemblyPath) {
    
    if(Test-Path Env:\APPVEYOR_BUILD_VERSION)
    {
        $appVeyorBuildVersion = $env:APPVEYOR_BUILD_VERSION
     
		# Getting the version number. Without the beta part, if its a beta package   
        $version = $appVeyorBuildVersion.Split('.')
        $major = $version[0] 
        $minor = $version[1] 
        $patch = $version[2].Split('-') | Select-Object -First 1

        # Setting beta postfix, if beta build. The beta number must be 5 digits, therefor this operation.
        $betaString = ""
        if($appVeyorBuildVersion.Contains("beta"))
        {
        	$buildNumber = $appVeyorBuildVersion.Split('-') | Select-Object -Last 1 | % {$_.replace("beta","")}
        	switch ($buildNumber.length) 
        	{	 
            	1 {$buildNumber = $buildNumber.Insert(0, '0').Insert(0, '0').Insert(0, '0').Insert(0, '0')} 
            	2 {$buildNumber = $buildNumber.Insert(0, '0').Insert(0, '0').Insert(0, '0')} 
            	3 {$buildNumber = $buildNumber.Insert(0, '0').Insert(0, '0')}
            	4 {$buildNumber = $buildNumber.Insert(0, '0')}                
            	default {$buildNumber = $buildNumber}
        	}
        	$betaString = "-beta$buildNumber" 
        }	
        return "$major.$minor.$patch$betaString"
    }
    else
    {
		#When building on local machine, set versionnumber from assembly info.
        $versionInfo = Get-Item $assemblyPath | % versioninfo
        return "$($versionInfo.FileVersion)"
    }
}

task default -depends Build-All, Test-All, Pack-All
task ci -depends Build-All, Test-All, Pack-All

task Pack-All -depends Pack-ConDep-Node
task Build-All -depends Clean, ResotreNugetPackages, Build, Check-VersionExists, Create-BuildSpec-ConDep-Node
task Test-All -depends Test

task Check-VersionExists {
	$version = $(GetNugetAssemblyVersion $build_directory\ConDep.Node\ConDepNode.exe)
	Exec { 
		$packages = & $nuget list "ConDep.Node" -source "https://www.myget.org/F/condep/api/v3/index.json" -prerelease -allversions
		ForEach($package in $packages){
			$packageName = $package.Split(' ') | Select-Object -First 1
			if($packageName -eq "ConDep.Node"){
				$packageVersionNumber = $package.Split(' ') | Select-Object -Last 1
				if($packageVersionNumber -eq $version){
					throw "ConDep.Node $packageVersionNumber already exists on myget. Have you forgot to update version in appveyor.yml?"
				}
			}
		}
	}
}

task ResotreNugetPackages {
	Exec { & $nuget restore "$pwd\..\src\condep-node.sln" }
}
	
task Build {
	Exec { msbuild "$pwd\..\src\condep-node.sln" /t:Build /p:Configuration=$configuration /p:OutDir=$build_directory /p:GenerateProjectSpecificOutputFolder=true}
}

task Clean {
	Write-Host "Cleaning Build output"  -ForegroundColor Green
	Remove-Item $build_directory -Force -Recurse -ErrorAction SilentlyContinue
}

task Test {

    $exclude = "--where=""cat != integration"""
	Exec { & $nunitPath\nunit3-console.exe $build_directory\ConDep.Node.Tests\ConDep.Node.Tests.dll $exclude --work=".\output" }
}

task Create-BuildSpec-ConDep-Node {
	Generate-Nuspec-File `
		-file "$build_directory\condep.node.nuspec" `
		-version $(GetNugetAssemblyVersion $build_directory\ConDep.Node\ConDepNode.exe) `
		-id "ConDep.Node" `
		-title "ConDep.Node" `
		-licenseUrl "http://www.condep.io/license/" `
		-projectUrl "http://www.condep.io/" `
		-description "ConDepNode is a Node deployed to remote servers by ConDep allowing easy remote interaction with servers." `
		-iconUrl "https://raw.github.com/condep/ConDep/master/images/ConDepNugetLogo.png" `
		-releaseNotes "$releaseNotes" `
		-tags "Continuous Deployment Delivery Infrastructure WebDeploy Deploy msdeploy IIS automation powershell remote" `
		-files @(
			@{ Path="ConDep.Node\ConDepNode.exe"; Target="lib/net45"}
		)
}

task Pack-ConDep-Node {
	Exec { & $nuget pack "$build_directory\condep.node.nuspec" -OutputDirectory "$build_directory" }
}