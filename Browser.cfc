<cfcomponent output="false" modifier="final" hint="Coldfusion representation of a browser, acting as a Coldfusion wrapper for Selenium's org.openqa.selenium.remote.RemoteWebDriver-class. Not all Selenium's Java methods are abstracted, but you can still access the original Java object using a public method." >
<cfprocessingdirective pageencoding="utf-8" />

	<cfset variables.oJavaWebDriver = "" /> <!--- Java object --->
	<cfset variables.oJavaBy = "" /> <!--- Java object --->
	<cfset variables.oElementLocator = "" /> <!--- CF component --->
	<cfset variables.oElementExistenceChecker = "" /> <!--- CF component --->
	<cfset variables.nWaitForDOMReadyStateTimeOut = 0 />
	<cfset variables.bFetchHiddenElements = false />
	<cfset variables.bUseStrictVisibilityCheck = true />
	<cfset variables.oJavaLoader = "" />
	<cfset variables.eventManager = "" />

	<!--- CONSTRUCTOR --->

	<cffunction name="init" returntype="Components.Browser" access="public" hint="Constructor" >
		<cfargument name="webDriverReference" type="any" required="true" hint="" />
		<cfargument name="waitForDOMReadyStateTimeOut" type="numeric" required="false" default="30" />
		<cfargument name="javaLoaderReference" type="any" required="false" />
		<cfargument name="eventManagerReference" type="Components.EventManager" required="false" />

		<cfif isObject(arguments.WebDriverReference) IS false >
			<cfthrow message="Error when initializing Browser" detail="Argument 'WebDriverReference' is not an object" />
		</cfif>

		<cfif structKeyExists(arguments, "eventManagerReference") >
			<cfset variables.eventManager = arguments.eventManagerReference />
		</cfif>

		<cfif structKeyExists(arguments, "javaLoaderReference") AND isObject(arguments.javaLoaderReference) >
			<cfset variables.oJavaLoader = arguments.javaLoaderReference />
			<cfset variables.oJavaBy = arguments.javaLoaderReference.create("org.openqa.selenium.By") />
		<cfelse>
			<cfset variables.oJavaBy = createObject("java", "org.openqa.selenium.By") />
		</cfif>

		<cfset variables.oElementLocator = new Components.ElementLocator(browserReference=this) />
		<cfset variables.oElementExistenceChecker = new Components.ElementExistenceChecker(browserReference=this) />

		<cfset variables.oJavaWebDriver = arguments.webDriverReference />
		<cfset variables.nWaitForDOMReadyStateTimeOut = arguments.waitForDOMReadyStateTimeOut />

		<cfreturn this />
	</cffunction>

	<!--- PRIVATE METHODS --->

	<cffunction name="fetchHTMLElements" returntype="array" access="private" hint="The primary mechanism for getting HTML elements. It is only used internally by this component, and other public methods act as facades for calling this." >
		<cfargument name="locator" type="Components.Locator" required="true" />
		<cfargument name="locateHiddenElements" type="boolean" required="true" />
		<cfargument name="searchContext" type="any" required="false" default="#variables.oJavaWebDriver#" hint="A reference to a Selenium Java-object, either the remote.RemoteWebDriver-class, or a remote.RemoteWebElement-class. This is the context in which the browser searches for elements. Normally this would be the browser/webdriver itself (within the document-node) but you can also search within DOM-elements using Selenium, just like you can in Javascript." />

		<cfset var aReturnData = arrayNew(1) />
		<cfset var stElementArguments = structNew() />
		<cfset stElementArguments.browserReference = this />
		<cfset var ReturnDataFromScript = "" />
		<cfset var aElementsFoundInDOM = arrayNew(1) />
		<cfset var oElement = "" />
		<cfset var CurrentJavascriptReturnData = "" />
		<cfset var oCurrentWebElement = "" />

		<cfif isObject(arguments.searchContext) IS false >
			<cfthrow message="Error fetching HTML element(s)" detail="Argument 'searchContext' is not an object" />
		</cfif>

		<!--- Wait for AJAX calls to complete --->
		<cfset variables.waitForDocumentToBeReady() />

		<cfif arguments.locator.getLocatorMechanism() IS "javascript" >

			<cfset ReturnDataFromScript = runJavascript(
				script=arguments.locator.getLocatorString(),
				parameters=arguments.locator.getJavascriptArguments(),
				asynchronous=false
			) />

			<cfif isDefined("ReturnDataFromScript") >

				<cfif isArray(ReturnDataFromScript) >

					<cfloop array="#ReturnDataFromScript#" index="CurrentJavascriptReturnData" >
						<cfif isObject(CurrentJavascriptReturnData) >
							<cfset arrayAppend( aElementsFoundInDOM, CurrentJavascriptReturnData ) />
						</cfif>
					</cfloop>

				<cfelse>

					<cfif isObject(ReturnDataFromScript) >
						<cfset arrayAppend( aElementsFoundInDOM, ReturnDataFromScript ) />
					</cfif>
				</cfif>
			</cfif>

		<cfelse>
			<cfset aElementsFoundInDOM = arguments.searchContext.findElements(arguments.locator.getSeleniumLocator()) />
		</cfif>

		<cfif arrayIsEmpty(aElementsFoundInDOM) IS false >

			<cfloop array="#aElementsFoundInDOM#" index="oCurrentWebElement" >
				<cfset stElementArguments.webElementReference = oCurrentWebElement />
				<cfset stElementArguments.locatorReference = arguments.locator />
				
				<cfif isObject(variables.eventManager) >
					<cfset stElementArguments.eventManagerReference = variables.eventManager />
				</cfif>

				<cfif arguments.locateHiddenElements IS false >

					<cfif variables.isElementFetchable(javaWebElement=oCurrentWebElement) >

						<cfset oElement = new Components.Element(argumentCollection = stElementArguments) />
						<cfset arrayAppend(aReturnData, oElement) />
					</cfif>

				<cfelse>

					<cfset oElement = new Components.Element(argumentCollection = stElementArguments) />
					<cfset arrayAppend(aReturnData, oElement) />
				</cfif>

			</cfloop>

		</cfif>

		<cfreturn aReturnData />
	</cffunction>

	<cffunction name="isElementFetchable" returntype="boolean" access="private" hint="" >
		<cfargument name="javaWebElement" type="any" required="true" />

		<cfif variables.bUseStrictVisibilityCheck >
			<cfreturn arguments.javaWebElement.isDisplayed() />
		</cfif>

		<!--- 
			Selenium's isDisplayed() method considers the same conditions but it also requires the element to be in the viewport
			and to be interactable/clickable (usually means not hidden/obscured behind other elements, fully or partially):
			https://stackoverflow.com/questions/18062372/how-does-selenium-webdrivers-isdisplayed-method-work
		--->
		<cfif 	(
					arguments.javaWebElement.size.height IS 0 OR
					arguments.javaWebElement.size.width IS 0
				)
					OR
				(
					arguments.javaWebElement.getCssValue("display") IS "none" OR
					arguments.javaWebElement.getCssValue("visibility") IS "hidden"
				) >

			<cfreturn false />
		</cfif>

		<cfreturn true />
	</cffunction>

	<!--- PUBLIC METHODS --->

	<cffunction name="useStrictVisibilityCheck" returntype="void" access="public" hint="Enable or disable the strict visibility check for fetching elements. The stricter check requires elements to be clickable (so not obscured behind other elements) and to be within the viewport. This is addition to the element required to be displayed, visible and have a height or width greater than 0." >
		<cfargument name="enable" type="boolean" required="true" />

		<cfif isObject(variables.eventManager) >
			<cfset variables.eventManager.log("Browser", getFunctionCalledName(), arguments) />
		</cfif>

		<cfset variables.bUseStrictVisibilityCheck = arguments.enable />
	</cffunction>

	<cffunction name="getFetchHiddenElements" returntype="boolean" access="public" hint="Returns true or false depending on whether the browser will fetch hidden HTML-elements." >
		<cfreturn variables.bFetchHiddenElements />
	</cffunction>

	<cffunction name="getJavaloader" returntype="any" access="public" hint="Returns a reference to the Javaloader. This is public because the injected components can then get it without us having to pass it on via init each time." >
		<cfreturn variables.oJavaLoader />
	</cffunction>

	<cffunction name="getJavaWebDriver" returntype="any" access="public" hint="Gets you a reference to the Java org.openqa.selenium.remote.RemoteWebDriver-class. The reason this is publicly exposed is because not all the Java methods have been abstracted so if you want (and you know what you are doing) you can access them directly." >
		<cfreturn variables.oJavaWebDriver />
	</cffunction>

	<cffunction name="setImplicitWait" returntype="void" access="public" hint="Use this method to enable or disable Selenium's mechanism for waiting while locating DOM elements. It's important to realize that this just makes the webdriver waits until the element is present in the DOM; it does not care about whether it's visible or clickable. NOTE: This lives alongside our own custom wait mechanism, which is meant for waiting for AJAX-calls to finish." >
		<cfargument name="timeout" type="numeric" required="false" default=0 hint="The timeout in seconds to wait for a DOM element to be located before proceeding. You can disable it by setting the timeout to 0, which is Selenium's default value." />

		<cfif isObject(variables.eventManager) >
			<cfset variables.eventManager.log("Browser", getFunctionCalledName(), arguments) />
		</cfif>

		<cfif isValid("integer", arguments.timeout) IS false >
			<cfthrow message="Error when setting implicit wait" detail="Argument 'timeout' must be a valid integer!" />
			<cfif arguments.Timeout LT 0 >
				<cfthrow message="Error when setting implicit wait" detail="Argument 'timeout' must be a positive number!" />
			</cfif>
		</cfif>

		<cfset variables.oJavaWebDriver.manage().timeouts().implicitlyWait(
			javaCast("long", arguments.timeout),
			createObject("java", "java.util.concurrent.TimeUnit").SECONDS
		) />
	</cffunction>

	<cffunction name="fetchHiddenElements" returntype="void" access="public" hint="Enable this to make the fetch-methods only return elements that are considered visible. Elements are not visible if their CSS values are set to display: none, visibility: hidden, they are obscured fully or partially behind other elements or they have no width and height." >
		<cfargument name="value" type="boolean" required="yes" />

		<cfif isObject(variables.eventManager) >
			<cfset variables.eventManager.log("Browser", getFunctionCalledName(), arguments) />
		</cfif>

		<cfset variables.bFetchHiddenElements = arguments.value />
	</cffunction>

	<cffunction name="getElementBy" returntype="Components.ElementLocator" access="public" hint="Returns an interface that contains handy methods designed to grab elements by specific, commonly used attributes such as id, class, title, name etc. If you want to do something more advanced - or just prefer more control - use getElement()." >
		<cfreturn variables.oElementLocator />
	</cffunction>

	<cffunction name="doElementsExist" returntype="Components.ElementExistenceChecker" access="public" hint="Returns an interface that contains handy methods designed to check the existence of elements by attribute or value. Existence checks are either binary (true/false) or based on amount." >
		<cfreturn variables.oElementExistenceChecker />
	</cffunction>

	<cffunction name="retryClickingElement" returntype="void" access="public" hint="Repeatedly tries to click on an element returned by the given locator for a given amount of attempts. Useful for working with what is the same element over and over in a loop or page refresh and you want to deal with Stale Element-exceptions." >
		<cfargument name="locator" type="Components.Locator" required="true" hint="An instance of the locator mechanism you want to use to search for the element" />
		<cfargument name="locateHiddenElements" type="boolean" required="false" default="#variables.bFetchHiddenElements#" hint="Use this to one-time override the default element fetch behaviour regarding returning only elements that are considered visible." />
		<cfargument name="attempts" type="numeric" required="false" default="1" hint="Amount of times to attempt clicking the element, ignoring all exceptions while doing so" />

		<cfif isObject(variables.eventManager) >
			<cfset variables.eventManager.log("Browser", getFunctionCalledName(), arguments) />
		</cfif>

		<cfset var nAttemptCount = 0 />
		<cfset var bSuccess = false />

		<cfloop from="1" to=#arguments.attempts# index="nAttemptCount" >

			<cfif bSuccess >
				<cfreturn/>
			</cfif>

			<cftry>

				<cfset variables.getElement(locator=arguments.locator, locateHiddenElements=arguments.locateHiddenElements).click() />
				<cfset bSuccess = true />

				<cfcatch>
					<cfif nAttemptCount NEQ arguments.attempts >
						<!--- Still trying to click the element so ignoring all exceptions and trying again after half a second --->
						<cfset sleep(500) />
					<cfelse>
						<cfrethrow />
					</cfif>
				</cfcatch>

			</cftry>
		</cfloop>
	</cffunction>

	<cffunction name="getElement" returntype="any" access="public" hint="Returns either the FIRST element or an array of ALL elements that matches your locator. If you search for multiple elements - and it finds nothing - you'll simply get an empty array. If you search for a single element - and it finds nothing - it will throw an error." >
		<cfargument name="locator" type="Components.Locator" required="true" hint="An instance of the locator mechanism you want to use to search for the element" />
		<cfargument name="locateHiddenElements" type="boolean" required="false" default="#variables.bFetchHiddenElements#" hint="Use this to one-time override the default element fetch behaviour regarding returning only elements that are considered visible." />
		<cfargument name="multiple" type="boolean" required="false" default="false" hint="Whether you want to fetch a single element or multiple. Keep in mind that this will return an array, even an empty one, if no elements are found." />

		<cfif isObject(variables.eventManager) >
			<cfset variables.eventManager.log("Browser", getFunctionCalledName(), arguments) />
		</cfif>

		<cfset var stFetchHTMLElementsArguments = arguments />
		<cfset var aElementCollection = arrayNew(1) />

		<cfif arguments.multiple >

			<cfset aElementCollection = fetchHTMLElements(argumentCollection = stFetchHTMLElementsArguments) />
			<cfreturn aElementCollection />

		<cfelse>
			<cfset aElementCollection = fetchHTMLElements(argumentCollection = stFetchHTMLElementsArguments) />

			<cfif arrayIsEmpty(aElementCollection) >
				<cfthrow message="Unable to find HTML-element" detail="Locator mechanism: #arguments.locator.getLocatorMechanism()# | Search string: #arguments.locator.getLocatorString()# | Locate hidden elements: #arguments.locateHiddenElements#" />
			</cfif>

			<cfif isInstanceOf(aElementCollection[1], "Components.Element") IS false >
				<cfthrow message="Unable to find HTML-element" detail="The first array entry returned from fetchHTMLElements() is not of type 'org.openqa.selenium.remote.RemoteWebElement'.
				Locator mechanism: #arguments.locator.getLocatorMechanism()# | Search string: #arguments.locator.getLocatorString()# | Locate hidden elements: #arguments.locateHiddenElements#" />
			</cfif>

			<cfreturn aElementCollection[1] />
		</cfif>
	</cffunction>

	<cffunction name="waitForDocumentToBeReady" returntype="void" access="private" hint="This method is used internally to wait for the document to be ready, primarily used to wait for AJAX-calls to complete. It checks both the DOM (document.readyState) and for calls made with jQuery (jQuery.active). It recursively calls itself until the document is ready or until the timeout is reached. Be aware that it returns as soon as the AJAX call itself is complete, which means the page may not be done rendering, which could still lead to issues. You may want to use waitUntil() or implement your own custom wait mechanism instead in that case." >
		<cfargument name="tickCountStart" type="numeric" required="false" default="#getTickCount()#" />

		<cfset sleep(100) />

		<cfset var nCurrentTickCount = getTickCount() />
		<cfset var bDocumentReadyState = false />
		<cfset var bJQueryReadyState = false />
		<cfset var nTimeDifference = 0 />
		<cfset var aJavascriptArguments = javaCast("java.lang.Object[]", arrayNew(1)) />
		<cfset var nTimeOut = variables.nWaitForDOMReadyStateTimeOut /> <!--- Be aware that it is not completely accurate. The function's execution time plus the sleep() adds a bit of overhead --->

		<cfset nTimeDifference = numberFormat(nCurrentTickCount/1000,'999') - numberFormat(arguments.tickCountStart/1000,'999') />

		<cfif nTimeDifference GT nTimeOut >
			<cfthrow message="Error while waiting for DOM to get ready" detail="WaitForDocumentToBeReady() hit the timeout before the DOM was ready. Timeout is: #nTimeOut#" />
			<cfreturn />
		</cfif>
		
		<cfset bDocumentReadyState = variables.oJavaWebDriver.executeScript(
			"return document.readyState === 'complete';",
			aJavascriptArguments
		) />
		<cfset bJQueryReadyState = variables.oJavaWebDriver.executeScript(
			"if (typeof jQuery === 'undefined') return true;
			if (jQuery.active === 0)return true;
			else return false;",
			aJavascriptArguments
		) />

		<cfif bDocumentReadyState IS true AND bJQueryReadyState IS true >
			<!--- End recursion, resume whatever else comes after the call to this function --->
			<cfreturn />	
		</cfif>

		<cfset waitForDocumentToBeReady(TickCountStart=arguments.tickCountStart) />
	</cffunction>

	<cffunction name="navigateTo" returntype="void" access="public" hint="Load a new web page in the current browser window." >
		<cfargument name="URL" type="string" required="true" />

		<cfif isObject(variables.eventManager) >
			<cfset variables.eventManager.log("Browser", getFunctionCalledName(), arguments) />
		</cfif>

		<cftry>
			<cfset createObject("java", "java.net.URL").init( arguments.URL ) />

			<cfcatch type="java.net.MalformedURLException">
				<cfthrow message="Error navigating to URL" detail="Either no legal protocol could be found in argument 'URL' or it could not be parsed as a URL. What you passed was: #arguments.URL#" />
			</cfcatch>
		</cftry>

		<cfset variables.oJavaWebDriver.get( arguments.URL ) />
	</cffunction>

	<cffunction name="quit" returntype="void" access="public" hint="Quits this driver, closing every associated window." >
		<cfif isObject(variables.eventManager) >
			<cfset variables.eventManager.log("Browser", getFunctionCalledName(), arguments) />
		</cfif>
		<cfreturn variables.oJavaWebDriver.quit() />
	</cffunction>

	<cffunction name="close" returntype="void" access="public" hint="Close the current window, quitting the browser if it's the last window currently open." >
		<cfif isObject(variables.eventManager) >
			<cfset variables.eventManager.log("Browser", getFunctionCalledName(), arguments) />
		</cfif>
		<cfreturn variables.oJavaWebDriver.close() />
	</cffunction>

	<cffunction name="runJavascript" returntype="any" access="public" hint="Executes Javascript on the current page. The script you provide will be executed as the body of an anonymous function. Note that local variables will not be available once the script has finished executing, though global variables will persist. If the script returns something Selenium will attempt to convert them. If the script returns nothing or the value is null, then it returns null. Note that it's entirely possible for you to use this method to return an element. However it will then be a Java-object (RemoteWebElement) rather than a CF component (Element.cfc). The proper way to get elements via JS is to use getElement()" >
		<cfargument name="script" type="string" required="true" hint="The javascript code to be executed. Be careful to escape quotes and other special characters or it will break. Also ensure that you actually put a return-statement in your script if you expect data back." />
		<cfargument name="parameters" type="array" required="false" default="#arrayNew(1)#" hint="Script arguments must be a number, a boolean, a string, RemoteWebElement, or an array of any of those combinations. The arguments will be made available to the JavaScript via the 'arguments' variable." />
		<cfargument name="asynchronous" type="boolean" required="false" default="false" hint="Unlike executing synchronous JavaScript, scripts executed with this method must explicitly signal they are finished by invoking the provided callback. This callback is always injected into the executed function as the last argument." />
		
		<cfif isObject(variables.eventManager) >
			<cfset variables.eventManager.log("Browser", getFunctionCalledName(), arguments) />
		</cfif>

		<cfset var ReturnDataFromScript = "" />

		<cfset var aJavascriptArguments = javaCast(
			"java.lang.Object[]",
			arguments.parameters
		) />

		<cfset waitForDocumentToBeReady() />

		<cftry>
	 		<cfif arguments.Asynchronous >
				<cfset ReturnDataFromScript = variables.oJavaWebDriver.executeAsyncScript(
					arguments.script,
					aJavascriptArguments
				) />
			<cfelse>
				<cfset ReturnDataFromScript = variables.oJavaWebDriver.executeScript(
					arguments.script,
					aJavascriptArguments
				) />
			</cfif>

			<cfcatch>
				<cfif cfcatch.type IS "org.openqa.selenium.JavascriptException" OR (cfcatch.type IS "org.openqa.selenium.WebDriverException" AND findNoCase("unknown error:", cfcatch.message) GT 0) >
					<cfthrow message="Error when executing Javascript | Script: #arguments.script# | Asynchronous: #arguments.asynchronous#" detail="#cfcatch.message#" />
				<cfelse>
					<cfrethrow/>
				</cfif>
			</cfcatch>
		</cftry>

		<!--- 	
			If executeScript() does not return something that can be converted then ReturnDataFromScript becomes 'undefined'. 
			Otherwise Selenium converts the results thus:
			
			For an HTML element, returns a WebElement
			For a decimal, a Double is returned
			For a non-decimal number, a Long is returned
			For a boolean, a Boolean is returned
			For all other cases, a String is returned.
			For an array, return a List<Object> with each object following the rules above.
			
			Since executeScript() can potentially return so many different datatypes we return null in case nothing is 
			returned so the caller can react accordingly.

			If an element isn't returned from this method, and you try to call methods on the result, you'll like get an 
			error along the lines of this: "Value must be initialized before use. Its possible that a method called on a 
			Java object created by CreateObject returned null."
		--->
		
		<cfif isDefined("ReturnDataFromScript") >
			<cfreturn ReturnDataFromScript />
		<cfelse>
			<cfreturn javaCast("null", 0) />
		</cfif>
	</cffunction>

	<cffunction name="takeScreenshot" returntype="any" access="public" hint="Capture a screenshot of the window currently in focus as PNG." >
		<cfargument name="format" type="string" required="false" default="bytes" hint="The format you want the screenshot returned as. Can return either base64, raw bytes or a java.io.File-object. Valid parameter strings are: 'bytes', 'base64' or 'file'." />

		<cfif isObject(variables.eventManager) >
			<cfset variables.eventManager.log("Browser", getFunctionCalledName(), arguments) />
		</cfif>

 		<cfset var sValidFormats = "bytes,base64,file" />
 		<cfset var oOutputType = "" />
 		<cfset var Type = "" />
 		<cfset var Screenshot = "" />

 		<cfif isObject(variables.oJavaLoader) >
			<cfset oOutputType = variables.oJavaLoader.create("org.openqa.selenium.OutputType") />
		<cfelse>
			<cfset oOutputType = createObject("java", "org.openqa.selenium.OutputType") />
		</cfif>

 		<cfif listFindNoCase(sValidFormats, arguments.format) GT 0 >

			<cfset Type = oOutputType[ uCase(arguments.format) ] />
			<cfset Screenshot = variables.oJavaWebDriver.getScreenshotAs(Type) />

		<cfelse>
			<cfthrow message="Error taking screenshot" detail="Argument 'Format' that you passed as '#arguments.format#' is not a valid format type. Valid formats are: #sValidFormats#" />	
		</cfif>

		<cfreturn Screenshot />
	</cffunction>

	<cffunction name="createLocator" returntype="Components.Locator" access="public" hint="Returns a Locator, which is in turn used to find elements with. The Locator on its own is not much use, but you can pass it as argument to methods like getElement() and waitUntil()." >
		<cfargument name="searchFor" type="string" required="true" hint="The string you want to search for" />
		<cfargument name="locateUsing" type="string" required="true" hint="The locator mechanism you want to use to find the element(s). Valid locators are: id,cssSelector,xpath,name,className,linkText,partialLinkText,tagName,javascript" />
		<cfargument name="javascriptArguments" type="array" required="false" default="#arrayNew(1)#" hint="Arguments for the javascript locator. Script arguments must be a number, a boolean, a string, RemoteWebElement, or an array of any of those combinations" />

		<cfif isObject(variables.eventManager) >
			<cfset variables.eventManager.log("Browser", getFunctionCalledName(), arguments) />
		</cfif>

		<cfreturn new Components.Locator(
			searchFor=arguments.searchFor,
			locateUsing=arguments.locateUsing,
			javascriptArguments=arguments.javascriptArguments,
			javaByReference=variables.oJavaBy
		) />
	</cffunction>

	<cffunction name="waitUntil" returntype="any" access="public" hint="Use this to wait for certain element conditions, such as for an element to be visible, clickable etc. This is mostly meants as a means of dealing with JS that manipulates the DOM, such as with animations, that you can't otherwise detect and wait for to finish." >
		<cfargument name="condition" type="string" required="true" hint="The name of the condition you want to wait for" />
		<cfargument name="elementOrLocator" type="any" required="true" hint="The argument for the condition. This is either a Locator or an Element. For some conditions it returns the element you passed or the element that would be found using the locator you passed. Some conditions (like invisibility) returns true once the condition is satisfied." />
		<cfargument name="timeout" type="numeric" required="false" default="10" hint="How long the browser should wait (in seconds) before throwing an error" />

		<cfif isObject(variables.eventManager) >
			<cfset variables.eventManager.log("Browser", getFunctionCalledName(), arguments) />
		</cfif>

		<!--- 
			HUGE disclaimer: Conditions that use locators are not subject to visibility checks!
		--->

		<cfset var ReturnData = "" />
		<cfset var oExpectedConditions = "" />
		<cfset var oExpectedConditionArgument = "" />
		<cfset var oWebdriverWait = "" />
		<cfset var stElementArguments = {} />

		<cfset var aValidConditions = [
			"visibilityOfElementLocated", <!--- Uses locators --->
			"visibilityOf", <!--- Uses web elements --->
			"invisibilityOf", <!--- Uses web elements --->
			"invisibilityOfElementLocated", <!--- Uses locators --->
			"elementToBeClickable", <!--- Uses both --->
			"presenceOfElementLocated" <!--- Uses locators --->
		] />

		<cfif arrayFind(aValidConditions, arguments.condition) IS 0 >
			<cfthrow message="Error when waiting for condition" detail="Argument 'condition' is not a valid condition. Valid conditions for use are: #arrayToList(aValidConditions)#" />
		</cfif>

		<cfif isValid("integer", arguments.timeout) IS false >
			<cfthrow message="Error when waiting for condition" detail="Argument 'timeout' must be a valid integer" />
			<cfif arguments.Timeout LTE 0 >
				<cfthrow message="Error when waiting for condition" detail="Argument 'timeout' must be a positive number" />
			</cfif>
		</cfif>

		<cfif isInstanceOf(arguments.elementOrLocator, "Components.Element") >
			<cfset oExpectedConditionArgument = arguments.elementOrLocator.getJavaWebElement() />
		<cfelseif isInstanceOf(arguments.elementOrLocator, "Components.Locator") >
			<cfset oExpectedConditionArgument = arguments.elementOrLocator.getSeleniumLocator() />
		<cfelse>
			<cfthrow message="Error when waiting for condition" detail="Argument 'elementOrLocator' is not an instance of Locator.cfc or Element.cfc" />
		</cfif>

		<cfif isObject(variables.oJavaLoader) >
			<cfset oExpectedConditions = variables.oJavaLoader.create("org.openqa.selenium.support.ui.ExpectedConditions") />
			<cfset oWebdriverWait = variables.oJavaLoader.create("org.openqa.selenium.support.ui.WebDriverWait").init(variables.oJavaWebDriver, javaCast("long", arguments.timeout)) />
		<cfelse>
			<cfset oExpectedConditions = createObject("java", "org.openqa.selenium.support.ui.ExpectedConditions") />
			<cfset oWebdriverWait = createObject("java", "org.openqa.selenium.support.ui.WebDriverWait").init(variables.oJavaWebDriver, javaCast("long", arguments.timeout)) />
		</cfif>
		
		<cftry>
			<cfset ReturnData = oWebdriverWait.until(
				invoke(oExpectedConditions, arguments.condition, [oExpectedConditionArgument])
			) />
		<cfcatch>

			<cfif cfcatch.type IS "org.openqa.selenium.TimeoutException" >
				<cfthrow type="BrowserWaitUntilTimeout" message="Error waiting for condition" detail="Timed out waiting for element with selector: #( isInstanceOf(arguments.elementOrLocator, "Locator") ? arguments.elementOrLocator.getLocatorString() : arguments.elementOrLocator.getLocator().getLocatorString() )#, to fullfill condition '#arguments.condition#'. Waited #arguments.timeout# seconds" />
			<cfelse>
				<cfrethrow />
			</cfif>

		</cfcatch>
		</cftry>

		<cfif isInstanceOf(arguments.elementOrLocator, "Locator") AND (isObject(ReturnData) AND ReturnData.getClass().getName() IS "org.openqa.selenium.remote.RemoteWebElement") >
			
			<cfset stElementArguments = {
				browserReference=this,
				webElementReference=ReturnData,
				locatorReference=arguments.elementOrLocator
			} />

			<cfif isObject(variables.eventManager) >
				<cfset stElementArguments.eventManagerReference = variables.eventManager />
			</cfif>

			<cfreturn new Components.Element(argumentCollection = stElementArguments) />

		<cfelseif isInstanceOf(arguments.elementOrLocator, "Components.Element") AND (isObject(ReturnData) AND ReturnData.getClass().getName() IS "org.openqa.selenium.remote.RemoteWebElement") >
			<cfreturn arguments.elementOrLocator />
		</cfif>

		<cfset sleep(100) />
		<cfreturn ReturnData />
	</cffunction>

</cfcomponent>