*** Settings ***
Documentation       This robot creates robot orders
...                 from CSV and afterwards saves
...                 orders to files.

Library    RPA.HTTP
Library    RPA.PDF
Library    Browser    auto_closing_level=SUITE
Library    csv
Library    RPA.Tables
Library    RPA.Archive
Library    RPA.Dialogs
Library    RPA.Robocorp.Vault

*** Variables ***
${DOWNLOAD_PATH}     ${OUTPUT_DIR}${/}orders.csv
${ORDER_URL}     https://robotsparebinindustries.com/
${CSV_URL}    https://robotsparebinindustries.com/orders.csv

*** Tasks ***
Make robot orders
    Log    Process starting!
     ${secret}=    Get Secret    topsecret
     ${ORDER_URL}=    Set Variable    ${secret}[url]
     #${DOWNLOAD_PATH}=    Set Variable     ${OUTPUT_DIR}${/}orders.csv

    Ask CSV url
    ${orders}=     Download CSV    

    FOR    ${order}    IN    @{orders}           
        Open Order Page In Browser
        Close modal
        Fill Order Form    order=${order}        
        Preview order
        ${screenshot}=    Save order screenshot    orderNo=${order}[Order number]
        Wait Until Keyword Succeeds    5x    2s    Submit order      
        ${pdf}=    Save order PDF    orderNo=${order}[Order number]
        Embed screenshot into PDF    ${pdf}    ${screenshot}
    END

    Zip all files
    Log    Process ready!

*** Keywords ***
Ask CSV url
    Add text input    url    label=Please enter source file
    ${response}=    Run dialog
    ${CSV_URL}=    Set Variable    ${response.url}

Download CSV
    RPA.HTTP.Download    ${CSV_URL}    overwrite=true    verify=true    target_file=${DOWNLOAD_PATH}
    ${data}=    Read table from CSV    path=${DOWNLOAD_PATH}
    RETURN    ${data}

Open Order Page In Browser
    Set Browser Timeout    5
    New Browser    headless=true
    New Page    url=${ORDER_URL} 
    Click    text="Order your robot!"
    
Close modal
    Click    text="Yep"

Fill order form
    [Arguments]     ${order}
    Log    ${order}
    Select Options By    id=head    value    ${order}[Head]
    Check Checkbox    xpath=//input[@value=${order}[Body]]
    Fill Text    xpath=//input[@placeholder="Enter the part number for the legs"]    ${order}[Legs]
    Fill Text    xpath=//input[@id="address"]    ${order}[Address]

Preview order
    Click    xpath=//button[@id="preview"]

Submit order
    TRY
        Click    xpath=//button[@id="order"]
        Get Element    xpath=//div[@id="receipt"]
    EXCEPT
        Log    Submit failed, retrying...
        Submit order   
    FINALLY
        Log     Submission ok
    END

Order another
    Click    xpath=//button[@id="order-another"]

Save order PDF
    [Arguments]    ${orderNo} 
    ${file}=    Set Variable    ${OUTPUT_DIR}${/}pdf${/}${orderNo}.pdf    
    Wait For Elements State    selector=xpath=//div[@id="receipt"]    state=visible
    ${reference} =    Get Element    xpath=//div[@id="receipt"]
    ${html}=    Get Property    ${reference}    innerText    
    Html To Pdf    ${html}    ${file}
    RETURN    ${file}

Save order screenshot
    [Arguments]    ${orderNo}
    ${file}=    Set Variable     ${OUTPUT_DIR}${/}png${/}${orderNo}.png
    Wait For Elements State    selector=xpath=//div[@id="robot-preview-image"]    state=visible
    # Sometimes images may download slowly (at least on slow virtual machine), so wait few seconds
    Sleep    2
    Take Screenshot    filename=${file}    fileType=png    selector=xpath=//div[@id="robot-preview-image"]
    RETURN     ${file}

Embed screenshot into PDF
    [Arguments]    ${pdf}    ${png}
    Log    ${png}
    ${writable}=    Open Pdf    ${pdf}
    ${files}=    Create List    ${png}:align=center

    Add Files To Pdf    files=${files}    target_document=${pdf}    append=true

Zip all files
    ${zip_file_name}=    Set Variable    ${OUTPUT_DIR}/pdf.zip
    ${path}=    Set Variable    ${OUTPUT_DIR}${/}pdf
    Archive Folder With Zip    folder=${path}    archive_name=${zip_file_name}
