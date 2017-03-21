> ExtensionList is inspired by [Applist](https://github.com/rpetrich/AppList). So the basic rules to use this library is very similar. 

> You can refer to [Applist manual](http://iphonedevwiki.net/index.php/AppList).

# Differences in 'ALSectionDescriptors'
## avaliable-extensions
The difference is that i removed the `suppress-hidden-apps` key for `ALSectionDescriptors`, because it's not appropriate for PlugIns. And I add a `avaliable-extensions` to filter only avaliable plugins that iOS version higher than the required iOS version. The default value for `avaliable-extensions` is `true`.
## predicate
`ExtensionList` query an array of `LSPlugInKitProxy` instance, so the `predicate` key is apply on the property of `LSPlugInKitProxy` class. There is a property named `protocol` in the said class, which infers to the Apple private service ID. For example, if you want to filter `Today-widget extension`, put `protocol contains 'com.apple.widget-extension'` into `predicate` key.
For further infomation about App Extension and the protocol refered to, you can see the [Apple Guides](https://developer.apple.com/library/content/documentation/General/Conceptual/ExtensibilityPG/Action.html#//apple_ref/doc/uid/TP40014214-CH13-SW1) about App Extension. Or you can find it in the `info.plist` of `*.appex`. The value for key `NSExtensionPointIdentifier` is equal to `protocol` of `LSPlugInKitProxy`.

- A demo of `ALSectionDescriptors`

```
ALSectionDescriptors = (
	{
		title = "Custom Keyboard";
		predicate = "protocol contains 'keyboard-service'";
		"icon-size" = 29;
		"cell-class-name" = ELSwitchCell;
		"avaliable-extensions" = 0;
	},
)
```
