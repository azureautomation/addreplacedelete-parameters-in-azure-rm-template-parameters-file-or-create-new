Add/replace/delete parameters in Azure RM template parameters file or create new
================================================================================

            

This function is used to edit or create template parameters files.


It either creates a new parameters file, or adds/replaces/deletes parameters in an existing parameters file. For example we might keep a template with a parameters file containing generic values, and when deploying to Azure, replace those values with values
 provided by the person requesting the deployment, then deploy.


The new parameters and their values are specified as a hash table, for example this hash table contains 2 parameters, 'name' and 'location', and their values:


@{'name'='MyResourceName';'location'='northeurope'}


If the function is given only a hash table it creates a new parameters file. If the function is given a hash table and an existing parameters file, it creates a new parameters file which contains the existing parameters file updated with the contents of
 the hash table.


If the same parameter is in the existing parameters file and the hash table, the value in the hash table is used. I created an optional switch parameter to override this, to keep the value in the existing parameters file, but I doubt if it will ever be used.


If the hash table contains a parameter that's not in the existing parameters file, the new parameter is added.


The function can also remove parameters from an existing parameters file, if they match an array of regex strings.


If a parameter value is an object, then it's specified as another hash table, for example this hash table has a 3rd parameter, 'sku', whose value is an object with 2 properties, 'family' and 'name':


@{'name'='myname'; 'location'='uksouth'; 'sku' = @{'family' = 'A'; 'name' = 'Standard'}}


It might be more readable to specify a hash table containing objects as parameter values as something like:


$myParams= @{
        'name' = 'myname';
        'location' = 'uksouth';
        'sku' = @{'family' = 'A'; 'name' = 'Standard'}
}


But even this approach can result in complex, nasty looking hash tables if the parameter values are complex objects, or arrays of them, I must admit! I have a function which creates a hash table containing a keyvault access policy if anyone's interested.
 If a parameter's value is a complicated object an alternative to using a function like this is to read the existing parameters file as an object and set its properties then write it again.


**Requirements:**
- I've used it on PS version 4 and 5. 
- Doesn't need the Azure module, it just reads and writes json files
- Doesn't need admin rights on the computer it runs on, just enough permissions to read the existing parameters file, and to write the new one


**Instructions:**
- Load the function in the ps1 file into memory without processing anything (dot sourcing) by running '. <path to script file>'
- The function is called New-AzureRmTemplateParametersFile, run 'Get-Help New-AzureRmTemplateParametersFile' to see its parameters


**Comments:**
- The new parameters file is json which has very large indents. This is done by the Microsoft cmdlet ConvertTo-Json. It's valid json so I just accepted it, some clever people on the internet have written functions to change the indents to smaller, more normal
 ones.


The snippet below is the code for adding/replacing/deleting parameters from an existing parameters file. It's more indented in the actual function.


 

 

        
    
TechNet gallery is retiring! This script was migrated from TechNet script center to GitHub by Microsoft Azure Automation product group. All the Script Center fields like Rating, RatingCount and DownloadCount have been carried over to Github as-is for the migrated scripts only. Note : The Script Center fields will not be applicable for the new repositories created in Github & hence those fields will not show up for new Github repositories.
