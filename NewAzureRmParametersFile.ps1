 function New-AzureRmTemplateParametersFile {
	<#
	.SYNOPSIS
	Can either create a new Azure RM template parameters file, or add/replace/remove parameters in an existing parameters file.
	.DESCRIPTION
	New parameters, or new values for existing parameters, are specified in a hash table. The keys are the parameter names, and the values are the parameter values.
	If a parameter's value is an object, then this object is specified as a hash table, so it's inside the hash table containing all the parameters and their values.
	If the input is only a hash table then a new parameters file is created containing those parameters and values.
	If the input is both a hash table and an existing parameters file, then the parameters in the hash table are used to update the ones in the parameters file. 
	If the same parameter name exists in both the hash table and the parameters file, the value from the hash table is used unless the function parameter InputFileOverridesSameParameterInHash is used, then the value from the parameters file is used.
	Unwanted parameters from the parameters file can be removed using RemoveParametersRegex function parameter which takes an array of regex strings. Parameter names matching any regex strings are removed.
	.EXAMPLE
	New-AzureRmTemplateParametersFile -ArmParametersHashTable @{'name'='myname'; 'location'='uksouth'; "sku" = @{"family" = "A"; "name" = "Standard"}} -OutputArmParametersFile 'C:\NewMyTemplateParameters.json'
	.EXAMPLE
	New-AzureRmTemplateParametersFile -ArmParametersHashTable @{'name'='MyResourceName';'location'='uksouth'} -InputArmParametersFile 'c:\MyExistingTemplateParameters.json' -OutputArmParametersFile 'C:\MyNewTemplateParameters.json'
	.EXAMPLE
	New-AzureRmTemplateParametersFile -ArmParametersHashTable @{'name'='MyResourceName';'location'='uksouth'} -InputArmParametersFile 'c:\MyExistingTemplateParameters.json' -InputFileOverridesSameParameterInHash -OutputArmParametersFile 'C:\MyNewTemplateParameters.json'
	.EXAMPLE
	New-AzureRmTemplateParametersFile -ArmParametersHashTable @{'name'='MyResourceName';'location'='uksouth'} -InputArmParametersFile 'c:\MyExistingTemplateParameters.json' -RemoveParametersRegex @('vaults_','^storage') -OutputArmParametersFile 'C:\MyNewTemplateParameters.json'
	.PARAMETER ArmParametersHashTable
	Hash table where the keys are the parameter names, the values are the parameter values.
	.PARAMETER InputArmParametersFile
	An existing Azure RM template parameters file.
	.PARAMETER InputFileOverridesSameParameterInHash
	If the same parameter name exists in the hash table and the input parameters file, if this function parameter is used the parameter value in InputArmParametersFile is kept, otherwise it is replaced by the value in the hash table.
	.PARAMETER RemoveParametersRegex
	An array of regex strings. Parameter names matching any regex strings are removed.
	.PARAMETER OutputArmParametersFile
	The output Azure RM template parameters file.
	#>
	[cmdletbinding()]
	Param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$True, ParameterSetName='CreateNewParametersFile')]
		[Parameter(Mandatory=$true, ValueFromPipeline=$True, ParameterSetName='EditExistingParametersFile')]
		[hashtable]$ArmParametersHashTable		# hash table of parameters
		,
		[Parameter(Mandatory=$true, ParameterSetName='EditExistingParametersFile')]
		[Parameter(Mandatory=$true, ParameterSetName='RemoveFromExistingParametersFile')]
		[ValidateScript({Test-Path $_})]
		[string]$InputArmParametersFile		# input template parameters file, parameters in the hash table will be added
		,
		[Parameter(Mandatory=$false, ParameterSetName='EditExistingParametersFile')]
		[switch]$InputFileOverridesSameParameterInHash		# if the same parameter exists in the input file and the hash table, if this parameter is used the parameter value in the input file is kept, otherwise the hash overwrites it.
		,
		[Parameter(Mandatory=$false, ParameterSetName='EditExistingParametersFile')]
		[Parameter(Mandatory=$true, ParameterSetName='RemoveFromExistingParametersFile')]
		[string[]]$RemoveParametersRegex		# array of regex strings, matching parameter names in $InputArmParametersFile are removed.
		,
		[Parameter(Mandatory=$true)]
		[ValidateScript({Test-Path -Path (Split-Path -Path $_)})]
		[string]$OutputArmParametersFile		# output json file
	)
	
	Set-StrictMode -version Latest
	$ErrorActionPreference = 'Stop'

	switch ($PsCmdlet.ParameterSetName) {
		'CreateNewParametersFile' {
			# Create an object to be written to the output json file
			$objOutput = New-Object PSCustomObject
			$objOutput | Add-Member -MemberType NoteProperty -name '$schema' -value 'https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#'
			$objOutput | Add-Member -MemberType NoteProperty -name 'contentVersion' -value '1.0.0.0'
			$objOutput | Add-Member -MemberType NoteProperty -name 'parameters' -value ([PSCustomObject]$null)

			# Also create a parameters object
			$objParameters = New-Object PSCustomObject

			# Add the key/value pairs in the hash table to the parameters object
			foreach ($Key in $ArmParametersHashTable.Keys) {
				if ($ArmParametersHashTable[$Key] -is [hashtable]) {
						$objParameters | Add-Member -MemberType NoteProperty -name $Key -value ([PsCustomObject]$ArmParametersHashTable[$Key]) 	# convert hash tables to PsCustomObject
				} else {
					$objParameters | Add-Member -MemberType NoteProperty -name $Key -value $(New-Object PSObject -Property @{'value' = $($ArmParametersHashTable[$Key])})
				}
			}
		}
		Default {
			# For both the other parameter sets, open $InputArmParametersFile
			if ($InputArmParametersFile -eq $OutputArmParametersFile) {
				Write-Error -Message "The output file `"$OutputArmParametersFile`" must be different from the input file `"$InputArmParametersFile`", terminating." -ErrorAction Stop
			}

			# Open $InputArmParametersFile, then convert from json to an object, then get the object for the Parameters node as another object
			try {
				$RawJsonText = Get-Content -Path $InputArmParametersFile -Raw
				$objOutput = ConvertFrom-Json -InputObject $RawJsonText
				if ((Get-Member -InputObject $objOutput -MemberType NoteProperty).Name -contains 'parameters') {
					$objParameters = $objOutput.parameters
				} else {
					$objParameters = New-Object PSCustomObject
					$objOutput | Add-Member -MemberType NoteProperty -name 'parameters' -value ([PSCustomObject]$null)
				}
			} catch {
				$PSCmdlet.ThrowTerminatingError($PSItem)
			}

			# Now process the other 2 parameter sets inside their own switch statement
			switch ($PsCmdlet.ParameterSetName) {
				'RemoveFromExistingParametersFile' {
					# Remove any matching parameters, no errors reported if not found
					if (Get-Member -InputObject $objParameters -MemberType NoteProperty) {
						$PropertiesToRemove = $objParameters.psobject.properties.name | Where-Object {$_ -match ($RemoveParametersRegex -join '|')}
						$PropertiesToRemove | ForEach-Object {$objParameters.psobject.properties.remove($_)}
					}
				}
				'EditExistingParametersFile' {
					foreach ($Key in $ArmParametersHashTable.Keys) {
						# If there are no properties, or no property called $Key, add the key/value pair from the hash table
						if (!(Get-Member -InputObject $objParameters -MemberType NoteProperty) -or ($objParameters.psobject.properties.name -notcontains $Key)) {
							if ($ArmParametersHashTable[$Key] -is [hashtable]) {
								$objParameters | Add-Member -MemberType NoteProperty -name $Key -value ([PsCustomObject]$ArmParametersHashTable[$Key]) 	# convert hash tables to PsCustomObject
							} else {
								$objParameters | Add-Member -MemberType NoteProperty -name $Key -value $(New-Object PSObject -Property @{'value' = $($ArmParametersHashTable[$Key])})
							}
						} elseif (!$InputFileOverridesSameParameterInHash) {
							# The property already exists. If $InputFileOverridesSameParameterInHash is not set, overwrite it
							if ($ArmParametersHashTable[$Key] -is [hashtable]) {
								$objParameters.$Key = ([PsCustomObject]$ArmParametersHashTable[$Key])
							} else {
								$objParameters.$Key = $(New-Object PSObject -Property @{'value' = $($ArmParametersHashTable[$Key])})
							}
						}
					}
					# If RemoveParametersRegex parameter is set, remove any matching parameters
					if ($RemoveParametersRegex) {
						if (Get-Member -InputObject $objParameters -MemberType NoteProperty) {
							$PropertiesToRemove = $objParameters.psobject.properties.name | Where-Object {$_ -match ($RemoveParametersRegex -join '|')}
							$PropertiesToRemove | ForEach-Object {$objParameters.psobject.properties.remove($_)}
						}
					}
				}
			}
		}
	}

	$objOutput.parameters = $objParameters
	
	# Write the output parameters file
	try {
		$objOutput  | ConvertTo-Json -depth 100 | Out-File $OutputArmParametersFile -Force -ErrorAction Stop
	} catch {
		$PSCmdlet.ThrowTerminatingError($PSItem)
	}
    return $objOutput
}

