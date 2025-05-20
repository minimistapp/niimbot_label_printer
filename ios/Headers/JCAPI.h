//version 3.2.8 20250315

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 It is recommended to use it on iOS 9 and above systems.
 */

/**
 Barcode mode enumeration.

 This enumeration defines different barcode formats, which can be used to identify and select specific barcode formats.

 - JCBarcodeFormatCodebar: CODEBAR 1D format.
 - JCBarcodeFormatCode39: Code 39 1D format.
 - JCBarcodeFormatCode93: Code 93 1D format.
 - JCBarcodeFormatCode128: Code 128 1D format.
 - JCBarcodeFormatEan8: EAN-8 1D format.
 - JCBarcodeFormatEan13: EAN-13 1D format.
 - JCBarcodeFormatITF: ITF (Interleaved Two of Five) 1D format.
 - JCBarcodeFormatUPCA: UPC-A 1D format.
 - JCBarcodeFormatUPCE: UPC-E 1D format.

 */
typedef NS_ENUM(NSUInteger, JCBarcodeMode){
    //CODEBAR 1D format.
    JCBarcodeFormatCodebar      ,
    
    //Code 39 1D format.
    JCBarcodeFormatCode39       ,
    
    //Code 93 1D format.
    JCBarcodeFormatCode93       ,
    
    //Code 128 1D format.
    JCBarcodeFormatCode128      ,
    
    //EAN-8 1D format.
    JCBarcodeFormatEan8         ,
    
    //EAN-13 1D format.
    JCBarcodeFormatEan13        ,
    
    //ITF (Interleaved Two of Five) 1D format.
    JCBarcodeFormatITF          ,
    
    //UPC-A 1D format.
    JCBarcodeFormatUPCA         ,
    
    //UPC-E 1D format.
    JCBarcodeFormatUPCE
};

typedef NS_ENUM(NSUInteger,JCSDKCacheStatus){
    JCSDKCacheWillPrinting,
    JCSDKCachePrinting,
    JCSDKCacheWillPause,
    JCSDKCachePaused,
    JCSDKCacheWillCancel,
    JCSDKCacheCanceled,
    JCSDKCacheWillDone,
    JCSDKCacheDone,
    JCSDKCacheWillResume,
    JCSDKCacheResumed,
} ;

typedef NS_ENUM(NSUInteger,JCSDKCammodFontType) {
    JCSDKCammodFontTypeStandard = 0,
    JCSDKCammodFontTypeFreestyleScript,
    JCSDKCammodFontTypeOCRA,
    JCSDKCammodFontTypeHelveticaNeueLTPro,
    JCSDKCammodFontTypeTimesNewRoman,
    JCSDKCammodFontTypeMICR,
    JCSDKCammodFontTypeTerU24b,
    JCSDKCammodFontTypeSimpleChinese16Point = 55,
    JCSDKCammodFontTypeSimpleChinese24Point
};

typedef NS_ENUM(NSUInteger,JCSDKCammodRotation) {
    JCSDKCammodRotationDefault = 0,
    JCSDKCammodRotation90 = 90,
    JCSDKCammodRotation180 = 180,
    JCSDKCammodRotation270 = 270
};

typedef NS_ENUM(NSUInteger,JCSDKCammodGraphicsType) {
    JCSDKCammodGraphicsTypeHorizontalExt ,
    JCSDKCammodGraphicsTypeVerticalExt,
    JCSDKCammodGraphicsTypeHorizontalZip,
    JCSDKCammodGraphicsTypeVerticalZip
};

typedef void (^DidOpened_Printer_Block) (BOOL isSuccess)                ;
typedef void (^DidPrinted_Block)        (BOOL isSuccess)                ;
typedef void (^PRINT_INFO)              (NSString * printInfo)          ;
typedef void (^PRINT_STATE)             (BOOL isSuccess)                ;
typedef void (^PRINT_DIC_INFO)          (NSDictionary * printDicInfo)   ;
typedef void (^JCSDKCACHE_STATE)        (JCSDKCacheStatus status)       ;


@interface JCAPI : NSObject
/**
 Scan for nearby Bluetooth printers.
 
 This method is used to scan for nearby Bluetooth printers and return a list of scanned printer names via a callback.
 
 @param completion Scan completion callback block. After the scan is complete, this callback will be called and an array of scanned Bluetooth printer names will be passed.
        The array `scanedPrinterNames` contains the names of the scanned Bluetooth printers. If no printers are scanned, the array is empty.
 */
+ (void)scanBluetoothPrinter:(void(^)(NSArray *scanedPrinterNames))completion;

/**
 Connect to a printer with the specified name via Bluetooth.
 
 This method is used to connect to a Bluetooth printer with the specified name. Changes in connection status will be notified through the passed callback.
 
 @param printerName The name of the Bluetooth printer to connect to.
 @param completion Connection status callback block. When the connection status changes, this callback will be called and the connection status result will be passed.
        The parameter `isSuccess` indicates whether the printer was successfully connected. YES means connection successful, NO means connection failed.
 */
+ (void)openPrinter:(NSString *)printerName
         completion:(DidOpened_Printer_Block)completion;


/**
 Scan for nearby Wi-Fi printers.
 
 This method is used to scan for nearby Wi-Fi printers and return a list of scanned printer information via a callback.
 
 @param completion Scan completion callback block. After the scan is complete, this callback will be called and an array of scanned Wi-Fi printer information will be passed.
        The array `scanedPrinterNames` contains the scanned Wi-Fi printer information. Each element is a dictionary containing the following fields:
        - `ipAdd`: The IP address of the printer.
        - `bleName`: Bluetooth name.
        - `port`: Connection port.
        - `availableClient`: Number of available client connections.
 */
+ (void)scanWifiPrinter:(void(^)(NSArray *scanedPrinterNames))completion;

/**
 Scan for nearby Wi-Fi printers.
 
 This method is used to scan for nearby Wi-Fi printers within the specified timeout period and return a list of scanned printer names via a callback.
 
 @param timeout Scan timeout period in seconds. The scan operation will be performed within this time.
 @param completion Scan completion callback block. After the scan is complete, this callback will be called and an array of scanned Wi-Fi printer names will be passed.
        The array `scanedPrinterNames` contains the names of the scanned Wi-Fi printers. If no printers are scanned, the array is empty.
 */
+ (void)scanWifiPrinter:(float)timeout withCompletion:(void(^)(NSArray *scanedPrinterNames))completion;

/**
Configure the printer to connect to the Wi-Fi currently connected to the mobile phone.
 
 @param   wifiName        Wi-Fi account (not required).
 @param   password        Wi-Fi password.
 @param   completion      Whether the printer successfully connected to Wi-Fi.
 */
+ (void)configurationWifi:(NSString *)wifiName
                 password:(NSString *)password
               completion:(PRINT_DIC_INFO)completion;

/**
 Get Wi-Fi network configuration information.

 This method is used to get Wi-Fi network configuration information, usually returning the Wi-Fi name.

 @param completion Callback for Wi-Fi name.
 */
+ (void)getWifiConfiguration:(PRINT_DIC_INFO)completion;




/**
 Get the name of the Wi-Fi currently connected to the mobile phone.

 This method is used to get the name of the Wi-Fi currently connected to the mobile phone.

 @return Returns the name of the Wi-Fi currently connected to the mobile phone.
 */
+ (NSString *)connectingWifiName;

/**
 Connect to a printer with the specified name via Wi-Fi.
 
 @param   host              Printer name.
 @param   completion      Whether the printer was successfully connected. (Connection status changes are returned through this callback)
 */
+(void)openPrinterHost:(NSString *)host
            completion:(DidOpened_Printer_Block)completion;

/**
Connect to the printer with the specified IP and perform Wi-Fi connection.
This method is used to establish a Wi-Fi connection with the printer at the specified IP address. Changes in connection status will be notified through the passed callback.

@param host The IP address of the printer, used to specify the printer to connect to.
@param completion Connection status callback block. When the connection status changes, this callback will be called and the connection status result will be passed.
       The parameter `isSuccess` indicates whether the printer was successfully connected. YES means connection successful, NO means connection failed.
*/
+(void)openPrinterHost:(NSString *)host
                  port:(uint16_t)port
            completion:(DidOpened_Printer_Block)completion;


/**
 Close the currently open printer connection.

 This method is used to close the currently open printer connection. After performing this operation, the `completion(NO)` callback of the `openPrinter:completion:` method will be triggered.

 Note: Calling this method will interrupt the connection with the printer.

 */
+ (void)closePrinter;


/**
 Get the name of the currently connected printer (Bluetooth or Wi-Fi).
 
 This method is used to get the name of the currently connected printer. For Wi-Fi connections, it returns the IP address of the printer.
 
 @return The name of the currently connected printer. Returns nil if no printer is connected.
 */
+ (NSString *)connectingPrinterName;

/**
 Get the current Bluetooth/Wi-Fi connection status.
 
 This method is used to get the current Bluetooth and Wi-Fi connection status of the device.
 
 @return Returns an integer representing the connection status. 0 means no connection, 1 means Bluetooth connected, 2 means Wi-Fi connected.
 */
+ (int)isConnectingState;

/**
Listen for printer status changes
 
 @param   completion
 @{
    @"1": Cover status - 0 open / 1 closed
    @"2": Battery level change - 1/2/3/4
    @"3": Whether paper is loaded - 0 no / 1 yes
    @"5": Ribbon status - 0 no ribbon / 1 ribbon present
    @"6": Wi-Fi signal strength
 }
 @return  Whether listening for printer status changes is supported: YES: supported, NO: not supported
 */
+ (BOOL)getPrintStatusChange:(PRINT_DIC_INFO)completion;


/**
 Get the label size installed in the printer (currently only supports M2 models, firmware version V1.24 and above)
 Note: When statusCode is 0 and paperType parameter is not 0, the read parameters are valid.
 @{@"statusCode":@"0",
    @"result":@{@"gapHeightPixel":arrs[0], //Gap height (black mark height) (unit: pixel)
            @"totalHeightPixel":arrs[1], //Paper height (including gap) (unit: pixel)
            @"paperType":arrs[2], //Paper type: 1: Gap paper; 2: Black mark paper; 3: Continuous paper; 4: Perforated paper; 5: Transparent paper; 6: Label;
            @"gapHeight":arrs[3], //Gap height (black mark height) (unit: mm)
            @"totalHeight":arrs[4], //Paper height (including gap) (unit: mm)
            @"paperWidthPixel":arrs[5], //Paper width (including gap) (unit: pixel)
            @"paperWidth":arrs[6], //Paper width (including gap) (unit: mm)
            @"direction":arrs[7], //Tail direction 1 up 2 down 3 left 4 right (not currently supported)
            @"tailLengthPixel":arrs[8], //Tail length (unit: pixel)
            @"tailLength":arrs[9]}} //Tail length (unit: mm)
 */
+ (void)getPaperInfo:(PRINT_DIC_INFO)completion;

/**
 Affects caching and pause functions. Up to 5 tasks can be cached to improve print continuity and enhance the printing experience.
  Whether to enable SDK caching: YES: enable, NO: disable
 */
    + (void)setPrintWithCache:(BOOL)startCache;

/**
 Pass in the total number of print copies before the printer starts printing.

 @param totalQuantityOfPrints Set the total number of print copies, which represents the sum of print copies for all pages. For example, if you need to print 3 pages, with the first page printed 3 times, the second page 2 times, and the third page 5 times, then the value of count should be 10 (3+2+5).
 */
+ (void)setTotalQuantityOfPrints:(NSInteger)totalQuantityOfPrints;

/**
 Cancel printing via Bluetooth/Wi-Fi (call if printing is not complete).
 
 @param   completion      Print end callback (will not be returned after an exception occurs)
 */
+ (void)cancelJob:(DidPrinted_Block)completion;

/**
 Printing completed via Bluetooth/Wi-Fi (call after printing is complete).
 
 @param   completion      Print end callback (will not be returned after an exception occurs)
 */
+ (void)endPrint:(DidPrinted_Block)completion;

/**
 Number of copies completed by Bluetooth/Wi-Fi price labeler (only valid for price labeler, may be partially lost, app should reset status on timeout).
 
 @param   count           Number of completed print copies (will not be returned after an exception occurs)
 @{
    @"totalCount":@"Total number of printed sheets" //Required key
    @"pageCount":@"Current copy number of the current page (PageNo)" //Optional
    @"pageNO":@"Current page number being printed" //Optional
    @"tid":@"TID code returned after writing to RFID"  //Optional
    @"carbonUsed":@"Ribbon usage, unit: mm"  //Optional
 }
 */
+ (void)getPrintingCountInfo:(PRINT_DIC_INFO)count;

/**
 Receive Bluetooth/Wi-Fi exceptions (call after successful connection).
 
 @param   error           Printing exception: 1: Cover open,
                                  2: Out of paper,
                                  3: Low battery,
                                  4: Battery abnormality,
                                  5: Manual stop,
                                  6: Data error,
                                    (Failed to submit print data - B3/Image generation failed/Sending data error, printer verification failed, printer returns)
                                  7: Temperature too high,
                                  8: Paper output abnormality,
 9-Printer busy (motor currently rotating (printing or feeding paper)/printer firmware upgrading)
 10-Print head not detected
 11-Ambient temperature too low
 12.Print head not locked
 13-Ribbon not detected
 14-Mismatched ribbon
 15-Used ribbon
 16-Unsupported paper type
 17-Failed to set paper
 18-Failed to set print mode
 19-Failed to set print density (printing allowed, only reports exception)
 20-Failed to write RFID
 21-Margin setting error
 (Margins must be greater than 0, top margin + bottom margin must be less than canvas height, left margin + right margin must be less than canvas width)
 22-Communication abnormality (timeout, printer commands consistently rejected)
 23-Printer disconnected
 24-Canvas parameter setting error
 25-Rotation angle parameter error
 26-JSON parameter error (PC)
 27-Paper output abnormality (cover open detection disabled)
 28-Check paper type
 29-When printing RFID labels in non-RFID mode
 30-Density setting not supported
 31-Unsupported print mode
 32-Label material setting failed (material setting timed out or failed, does not block normal printing)
 33-Unsupported label material setting (blocks normal printing)
 34-Printer abnormality (blocks normal printing)
 35-Cutter abnormality (T2 blocks normal printing)
 36-Out of paper (T2 no paper loaded)
 37-Printer abnormality (T2 cannot be recovered by command, requires manual printer operation)
 50-Illegal label
 51-Illegal ribbon and label
 */
+ (void)getPrintingErrorInfo:(PRINT_INFO)error;

/**
Pixel to millimeter (pixels will be processed).
 
 @param   pixel           Pixel
 @return  Drawing parameter
 */
+ (CGFloat)pixelToMm:(CGFloat)pixel;

/**
Millimeter to pixel (millimeters will be processed).

 @param  mm       Millimeter
 @return  Drawing parameter
 */
+ (CGFloat)mmToPixel:(CGFloat)mm;


/**
 Generate print preview image.
 
 This method is used to generate a print preview image based on the provided JSON data, resolution, and print magnification parameters.

 @param generatePrintPreviewImageJson JSON data containing print information.
 @param displayMultiple Display magnification, used to specify the resolution of the generated image.
 @param printMultiple Printer magnification, used to specify the print magnification of the generated image.
 @param printPreviewImageType Preview image type, usually a fixed value of 1.
 @param error Pointer to an NSError object to receive error information. If an error occurs during preview image generation, corresponding error information will be returned.

 @return Returns the generated preview image, or nil if generation fails.
 */
+ (UIImage *)generatePrintPreviewImage:(NSString*)generatePrintPreviewImageJson displayMultiple:(float)displayMultiple printMultiple:(float)printMultiple printPreviewImageType:(int)printPreviewImageType error:(NSError **)error;


/**
 Initialize image library.
 
 This method is used to set the path of the font folder for subsequent image processing operations. Before performing text drawing and 1D code text drawing, the image library must be initialized first.
 
 @param fontFamilyPath The full path of the font folder.
 @param error Pointer to an NSError object to receive error information. If an error occurs when setting the font path, corresponding error information will be returned.
 
 @note
 Before performing text drawing and 1D code text drawing, please ensure that this method is called first to initialize the image library. If initialization fails, error information will be returned through the `error` parameter.
 */
+(void) initImageProcessing:(NSString *) fontFamilyPath error:(NSError **)error;

/**
 Prepare print job.
 
 This method is used to prepare a print job, set print density and paper type, and notify the result through a callback after printing is complete.
 
 @param blackRules Print density setting. The specific value depends on the printer model, refer to the following rules:
   - B series thermal models (B3S/B21/B203/B1/B31): Supports range 1~5, default value 3.
   - K series thermal models (K3/K3W): Supports range 1~5, default value 3.
   - D series thermal models (D11/D110/D101): Supports range 1~3, default value 2.
   - B16 thermal model: Supports range 1~3, default value 2.
   - Thermal transfer models Z401/B32: Supports range 1~15, default value 8.
   - Thermal transfer models P1/P1S: Supports range 1~5, default value 3.
   - Thermal transfer model B18: Supports range 1~3, default value 2.
   - B11/B50/T7/T8 series: 0 (follow printer settings), 1 (lightest), 6 (normal), 15 (darkest)
 
 @param paperStyle Paper type setting. The specific value depends on the printer model, refer to the following rules:
   - B3S/B21/B203/B1/B16/D11/D110/D101/Z401/B32/K3/K3W/P1/P1S:
     1—Gap paper
     2—Black mark paper
     3—Continuous paper
     4—Perforated paper
     5—Transparent paper
     6—Label
 
   - B11/B50/T7/T8 series:
     0: Continuous paper
     1: Positioning hole (if positioning hole is not supported, automatically switch to gap paper)
     2: Gap paper
     3: Black mark paper
 
 @param completion Print completion callback block. When the print job is complete, this callback will be called and the print result will be passed.
 */
+ (void)startJob:(int)blackRules
  withPaperStyle:(int)paperStyle
  withCompletion:(DidPrinted_Block)completion;

/**
 Print binarized image bitmap data.
 
 This method is used to submit binarized image data to the printer. You can set the number of copies, whether there is a dashed line, and a callback after printing is complete.

 @param data NSData object containing binarized image data.
 @param width Image width.
 @param height Image height.
 @param count Number of print copies.
 @param hasDashLine Whether to include a dashed line.
 @param completion Print completion callback block. When the print job is complete, this callback will be called and the print result will be passed.
 */
+ (void)print:(nonnull NSData *)data
    dataWidth:(unsigned int)width
   dataHeight:(unsigned int)height
    withCount:(unsigned int)count
      withEpc:(nullable NSString *)epcCode
 withComplete:(DidPrinted_Block)completion;

/**
 Print binarized image bitmap data.
 
 This method is used to submit binarized image data to the printer. You can set the number of copies, EPC code, whether there is a dashed line, and a callback after printing is complete.

 @param data NSData object containing binarized image data.
 @param width Image width.
 @param height Image height.
 @param count Number of print copies.
 @param epcCode EPC code (optional).
 @param hasDashLine Whether to include a dashed line.
 @param completion Print completion callback block. When the print job is complete, this callback will be called and the print result will be passed.
 */
+ (void)print:(nonnull NSData *)data
    dataWidth:(unsigned int)width
   dataHeight:(unsigned int)height
    withCount:(unsigned int)count
      withEpc:(nullable NSString *)epcCode
 withDashLine:(BOOL)hasDashLine
 withComplete:(DidPrinted_Block)completion;

/**
 Millimeter to pixel.
 
 This method is used to convert length in millimeters to pixels, considering the scaling factor.

 @param mm Millimeter value.
 @param scaler Scaling factor.
 @return Returns an integer representing the converted pixel value.
 */
+ (int) mmToPixel:(float)mm scaler:(float)scaler;

/**
 Pixel to millimeter.
 
 This method is used to convert length in pixels to millimeters, considering the scaling factor.

 @param pixel Pixel value.
 @param scaler Scaling factor.
 @return Returns a floating-point number representing the converted millimeter value.
 */
+ (float) pixelToMm:(int)pixel scaler:(float)scaler;

/**
 Get display multiple.
 
 This method is used to calculate the display multiple, combining the screen physical size with the screen resolution.

 @param templatePhysical Screen physical size (millimeters).
 @param screenDisplaySize Screen resolution width (pixels).
 @return Returns a floating-point number representing the calculated display multiple.
 */
+ (float)getDisplayMultiple:(float)templatePhysical templateDisplayWidth:(int)screenDisplaySize;


/**
 Millimeter to inch.
 
 This method is used to convert length in millimeters to inches.

 @param mm Millimeter value.
 @return Returns a floating-point number representing the converted inch value.
 */
+(float) mmToInch:(float) mm;

/**
 Inch to millimeter.
 
 This method is used to convert length in inches to millimeters.

 @param inch Inch value.
 @return Returns a floating-point number representing the converted millimeter value.
 */
+(float) inchToMm:(float) inch;


/// Whether RFID writing function is supported
+(BOOL)isSupportWriteRFID;


/**
 Initialize drawing board.
 
 This method is used to initialize a drawing board, specifying width, height, horizontal offset, vertical offset, rotation angle, and optional font path.

 @param width Width of the drawing board (millimeters).
 @param height Height of the drawing board (millimeters).
 @param horizontalShift Horizontal offset of the drawing board (millimeters) (not yet effective).
 @param verticalShift Vertical offset of the drawing board (millimeters) (not yet effective).
 @param rotate Rotation angle of the drawing board, usually 0.
 @param font Font name (not yet effective)
 */
+(void)initDrawingBoard:(float)width
             withHeight:(float)height
    withHorizontalShift:(float)horizontalShift
      withVerticalShift:(float)verticalShift
                 rotate:(int) rotate
                   font:(NSString*)font;


/**
 Initialize drawing board.
 
 This method is used to initialize a drawing board, specifying width, height, horizontal offset, vertical offset, rotation angle, and optional font path.

 @param width Width of the drawing board (millimeters).
 @param height Height of the drawing board (millimeters).
 @param horizontalShift Horizontal offset of the drawing board (millimeters) (not yet effective).
 @param verticalShift Vertical offset of the drawing board (millimeters) (not yet effective).
 @param rotate Rotation angle of the drawing board, usually 0.
 @param fonts Font array
 */
+(void)initDrawingBoard:(float)width
             withHeight:(float)height
    withHorizontalShift:(float)horizontalShift
      withVerticalShift:(float)verticalShift
                 rotate:(int) rotate
              fontArray:(NSArray<NSString*> *)fonts;

/**
 Draw text.
 
 This method is used to draw text on the drawing board. You can specify the text's position, size, content, font, font size, rotation angle, alignment, line wrapping, and font style.

 @param x Horizontal starting point (millimeters).
 @param y Vertical starting point (millimeters).
 @param w Width (millimeters).
 @param h Height (millimeters).
 @param text Text content.
 @param fontFamily Font name.
 @param fontSize Font size.
 @param rotate Rotation angle.
 @param textAlignHorizonral Horizontal text alignment: 0 (left), 1 (center), 2 (right).
 @param textAlignVertical Vertical text alignment: 0 (top), 1 (middle), 2 (bottom).
 @param lineMode Line wrapping mode.
 @param letterSpacing Letter spacing.
 @param lineSpacing Line spacing.
 @param fontStyles Font styles, an array of boolean values, usually including italic, bold, underline, strikethrough.

 @return Returns a boolean value indicating whether the text was successfully drawn.
 
 @note
 Before drawing text, please ensure that this method is called first to initialize the image library.
 */
+(BOOL)drawLableText:(float)x
               withY:(float)y
           withWidth:(float)w
          withHeight:(float)h
          withString:(NSString *)text
      withFontFamily:(NSString *)fontFamily
        withFontSize:(float)fontSize
          withRotate:(int)rotate
withTextAlignHorizonral:(int)textAlignHorizonral
withTextAlignVertical:(int)textAlignVertical
        withLineMode:(int)lineMode
   withLetterSpacing:(float)letterSpacing
     withLineSpacing:(float)lineSpacing
       withFontStyle:(NSArray <NSNumber *>*)fontStyles;


/**
 Draw 1D barcode.
 
 This method is used to draw a 1D barcode on the drawing board. You can specify the barcode's position, size, content, font size, rotation angle, type, and related text information.

 @param x Horizontal coordinate (millimeters).
 @param y Vertical coordinate (millimeters).
 @param w Barcode width (millimeters).
 @param h Barcode height (millimeters) (including text height).
 @param text Barcode content.
 @param fontSize Text font size.
 @param rotate Rotation angle, supports only 0, 90, 180, 270.
 @param codeType 1D barcode type:
   - 20: CODE128
   - 21: UPC-A
   - 22: UPC-E
   - 23: EAN8
   - 24: EAN13
   - 25: CODE93
   - 26: CODE39
   - 27: CODEBAR
   - 28: ITF25
 @param textHeight Text height (millimeters).
 @param textPosition Display position of the human-readable text for the 1D barcode:
   - 0: Display below
   - 1: Display above
   - 2: Do not display

 @return Returns a boolean value indicating whether the barcode was successfully drawn.
 
 @note
 Before drawing a 1D barcode, please ensure that this method is called first to initialize the image library.
 */
+(BOOL)drawLableBarCode:(float)x
                  withY:(float)y
              withWidth:(float)w
             withHeight:(float)h
             withString:(NSString *)text
           withFontSize:(float)fontSize
             withRotate:(int)rotate
           withCodeType:(int)codeType
         withTextHeight:(float)textHeight
       withTextPosition:(int)textPosition;


/**
 Draw QR code.
 
 This method is used to draw a QR code on the drawing board. You can specify the QR code's position, size, content, rotation angle, and type.

 @param x Horizontal coordinate (millimeters).
 @param y Vertical coordinate (millimeters).
 @param w QR code width (millimeters).
 @param h QR code height (millimeters).
 @param text QR code content.
 @param rotate Rotation angle, supports only 0, 90, 180, 270.
 @param codeType QR code type:
   - 31: QR_CODE
   - 32: PDF417
   - 33: DATA_MATRIX
   - 34: AZTEC

 @return Returns a boolean value indicating whether the QR code was successfully drawn.
 */
+(BOOL)drawLableQrCode:(float)x
                 withY:(float)y
             withWidth:(float)w
            withHeight:(float)h
            withString:(NSString *)text
            withRotate:(int)rotate
          withCodeType:(int)codeType;


/**
 Draw line.
 
 This method is used to draw a line on the drawing board. You can specify the line's position, size, rotation angle, type, and the width and style of dashed lines.

 @param x Horizontal coordinate (millimeters).
 @param y Vertical coordinate (millimeters).
 @param w Line width (millimeters).
 @param h Line height (millimeters).
 @param rotate Rotation angle, supports only 0, 90, 180, 270.
 @param lineType Line type:
   - 1: Solid line
   - 2: Dashed line type, dash-space ratio 1:1.
 @param dashWidth Width of the dashed line, an array of two numbers representing the length of the solid segment and the length of the empty segment.

 @return Returns a boolean value indicating whether the line was successfully drawn.
 */
+(BOOL)DrawLableLine:(float)x
               withY:(float)y
           withWidth:(float)w
          withHeight:(float)h
          withRotate:(int)rotate
        withLineType:(int)lineType
       withDashWidth:(NSArray <NSNumber *>*)dashWidth;


/**
 Draw shape.
 
 This method is used to draw a shape on the drawing board. You can specify the shape's position, size, line width, corner radius, rotation angle, type, and line style.

 @param x Horizontal coordinate (millimeters).
 @param y Vertical coordinate (millimeters).
 @param w Shape width (millimeters).
 @param h Shape height (millimeters).
 @param lineWidth Line width (millimeters).
 @param cornerRadius Image corner radius (millimeters).
 @param rotate Rotation angle, supports only 0, 90, 180, 270.
 @param graphType Graphic type.
 @param lineType Line type:
   - 1: Solid line
   - 2: Dashed line type, dash-space ratio 1:1.
 @param dashWidth Line width, an array of two numbers representing the length of the solid segment and the length of the empty segment.

 @return Returns a boolean value indicating whether the shape was successfully drawn.
 */
+(BOOL)DrawLableGraph:(float)x
                withY:(float)y
            withWidth:(float)w
           withHeight:(float)h
        withLineWidth:(float)lineWidth
     withCornerRadius:(float)cornerRadius
           withRotate:(int)rotate
        withGraphType:(int)graphType
         withLineType:(int)lineType
        withDashWidth:(NSArray <NSNumber *>*)dashWidth;


/**
 Draw image.
 
 This method is used to draw an image on the drawing board. You can specify the image's position, size, image data, rotation angle, processing algorithm, and threshold.

 @param x Horizontal coordinate (millimeters).
 @param y Vertical coordinate (millimeters).
 @param w Image width (millimeters).
 @param h Image height (millimeters).
 @param imageData Base64 data of the image.
 @param rotate Rotation angle, supports only 0, 90, 180, 270.
 @param imageProcessingType Image processing algorithm (default 1).
 @param imageProcessingValue Threshold (default 127).

 @return Returns a boolean value indicating whether the image was successfully drawn.
 */
+(BOOL)DrawLableImage:(float)x
                withY:(float)y
            withWidth:(float)w
           withHeight:(float)h
        withImageData:(NSString *)imageData
           withRotate:(int)rotate
withImageProcessingType:(int)imageProcessingType
withImageProcessingValue:(float)imageProcessingValue;

/**
 Generate JSON string for label data.

 This method is used to generate a JSON string for label data to be submitted to the printer for printing.

 @return Returns the generated JSON string for label data.
 */
+(NSString *)GenerateLableJson;


/**
 Get label preview image.

 This method is used to generate a preview image of the label. You can specify the display magnification and error code.

 @param displayScale Display magnification.
 @param error Returned error code. If successful, error is nil.

 @return Returns the generated label preview image.
 */
+(UIImage *)generateImagePreviewImage:(float)displayScale error:(NSError **)error;


/**
 Start printing label job.

 This method is used to submit print data, specify the number of copies, and handle callbacks.

 @param printData Print data, usually a JSON string of the label.
 @param onePageNumbers Used to specify the number of print copies for the current page. For example, if you need to print 3 pages, with the first page printed 3 times, the second page 2 times, and the third page 5 times, then when submitting data 3 times, the onePageNumbers values should be 3, 2, and 5 respectively.
 @param completion Print completion callback, used to handle the result of whether the print job was successful.

 */
+ (void)commit:(NSString *)printData
withOnePageNumbers:(int)onePageNumbers
  withComplete:(DidPrinted_Block)completion;

/**
 Start printing label job.

 This method is used to submit print data, specify the number of copies, RFID data to write, and handle callbacks.

 @param printData Print data, usually a JSON string of the label.
 @param onePageNumbers Used to specify the number of print copies for the current page. For example, if you need to print 3 pages, with the first page printed 3 times, the second page 2 times, and the third page 5 times, then when submitting data 3 times, the onePageNumbers values should be 3, 2, and 5 respectively.
 @param epcCode RFID data to write. Can be nil, indicating no RFID data will be written. (Only supports B32R model)
 @param completion Print completion callback, used to handle the result of whether the print job was successful.
 */
+ (void)commit:(NSString *)printData
withOnePageNumbers:(int)onePageNumbers
       withEpc:(nullable NSString *)epcCode
  withComplete:(DidPrinted_Block)completion;

@end

