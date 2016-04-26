# NSObject-TCMapping

Category for NSArray, NSDictionary

- JSON -> Model

- Model -> JSON

- Auto NSCopying

- Auto NSCoding

- Auto Hash

- Auto Equal

- Custom Struct support


## features

### JSON <--> Model 

```
 CGPoint <-> "{x,y}"
 CGVector <-> "{dx, dy}"
 CGSize <-> "{w, h}"
 CGRect <-> "{{x,y},{w, h}}"
 CGAffineTransform <-> "{a, b, c, d, tx, ty}"
 UIEdgeInsets <-> "{top, left, bottom, right}"
 UIOffset <-> "{horizontal, vertical}"
 
 UIColor <-> {r:0~1, g:0~1, b:0~1, a:0~1}, {rgb:0x322834}, {rgba:0x12345678}, {argb:0x12345678}

 NSData <-> base64 string
 NSDate <-> "yyyy-MM-dd'T'HH:mm:ssZ"
 NSURL <-> string
 NSAttributedString <-> string
 SEL <-> string
```

### NSCoding

```
NSNull <-> "<null>"
```




