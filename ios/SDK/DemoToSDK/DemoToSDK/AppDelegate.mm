//
//  AppDelegate.m
//  DemoToSDK
//
//  Created by jc on 2023/8/25.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  // Override point for customization after application launch.
  [self loadFonts];
  return YES;
}

// Copy file from source path to destination path // 从源路径复制文件到目标路径
- (void)copyFileFromPath:(NSString *)sourcePath toPath:(NSString *)toPath {
  // Initialize file manager to handle file operations //
  // 初始化文件管理器以处理文件操作
  NSFileManager *fileManager = [[NSFileManager alloc] init];

  // Get contents of the source path directory // 获取源路径目录中的内容
  NSArray *array = [fileManager contentsOfDirectoryAtPath:sourcePath error:nil];

  // Iterate through each item in the directory // 遍历目录中的每一项
  for (int i = 0; i < [array count]; i++) {
    // Build the full path of the current item in the source directory //
    // 构建当前项在源目录中的完整路径
    NSString *fullPath =
        [sourcePath stringByAppendingPathComponent:[array objectAtIndex:i]];

    // Build the full path of the current item in the destination directory //
    // 构建当前项在目标目录中的完整路径
    NSString *fullToPath =
        [toPath stringByAppendingPathComponent:[array objectAtIndex:i]];

    // Output source and destination paths for debugging //
    // 输出源路径和目标路径以进行调试
    NSLog(@"Output source path %@", fullPath);        // @"输出源路径%@"
    NSLog(@"Output destination path %@", fullToPath); // @"输出目标路径%@"

    // Mark whether the current item is a folder // 标记当前项是否为文件夹
    BOOL isFolder = NO;

    // Check if the item at the path exists and determine if it is a folder //
    // 检查路径下的项目是否存在并确定其是否为文件夹
    BOOL isExist = [fileManager fileExistsAtPath:fullPath
                                     isDirectory:&isFolder];

    if (isExist) {
      NSError *err = nil;
      // Copy item from source path to destination path //
      // 从源路径复制项目到目标路径
      [[NSFileManager defaultManager] copyItemAtPath:fullPath
                                              toPath:fullToPath
                                               error:&err];

      // Log any errors encountered during the copy operation //
      // 记录复制操作中遇到的错误
      NSLog(@"%@", err);

      // If the item is a folder, recursively copy its contents //
      // 如果项目是文件夹，则递归复制其内容
      if (isFolder) {
        [self copyFileFromPath:fullPath toPath:fullToPath];
      }
    }
  }
}

// Load fonts from JSON file and copy them to a specific directory // 从 JSON
// 文件加载字体并将其复制到特定目录
- (void)loadFonts {
  // Get the path to the FONT.json file in the main bundle // 获取主包中
  // FONT.json 文件的路径
  NSString *path = [[NSBundle mainBundle] pathForResource:@"FONT.json"
                                                   ofType:nil];
  NSLog(@"test01");

  // Read the JSON file content into a string // 将 JSON 文件内容读取为字符串
  NSString *str = [[NSString alloc] initWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
  NSLog(@"test02");

  if (str) {
    NSLog(@"test03");
    // Convert string to JSON data // 将字符串转换为 JSON 数据
    NSData *jsonData = [str dataUsingEncoding:NSUTF8StringEncoding];
    NSLog(@"test04");
    if (jsonData) {
      NSLog(@"test05");
      NSError *err;
      // Deserialize JSON data into a dictionary // 将 JSON 数据反序列化为字典
      NSDictionary *dic =
          [NSJSONSerialization JSONObjectWithData:jsonData
                                          options:NSJSONReadingMutableContainers
                                            error:&err];
      NSLog(@"test06");
      if (dic) {
        NSLog(@"test07");
        // Get font array from dictionary // 从字典中获取字体数组
        NSArray *arr = [dic valueForKey:@"fonts"];
        NSLog(@"test08");
        if (arr) {
          NSLog(@"test09");
          // Build the path to the font directory in the Documents folder //
          // 构建文档文件夹中字体目录的路径
          NSString *fontPath = [NSString
              stringWithFormat:@"%@/font",
                               [NSHomeDirectory()
                                   stringByAppendingString:@"/Documents"]];

          // Initialize file manager to handle file operations //
          // 初始化文件管理器以处理文件操作
          NSFileManager *manager = [NSFileManager defaultManager];
          NSLog(@"test10");
          // Check if the font directory does not exist, then create it //
          // 检查字体目录是否不存在，然后创建它
          if (![manager contentsOfDirectoryAtPath:fontPath error:nil]) {
            NSLog(@"test11");
            [manager createDirectoryAtPath:fontPath
                withIntermediateDirectories:NO
                                 attributes:nil
                                      error:nil];
          }
          NSLog(@"test12");
          // Iterate through each font dictionary in the array //
          // 遍历数组中的每个字体字典
          for (NSDictionary *obj in arr) {
            // Get the URL of the font // 获取字体的 URL
            NSString *name = [obj valueForKey:@"url"];

            // Build the new path for the font in the destination directory //
            // 构建目标目录中字体的新路径
            NSString *newPath =
                [NSString stringWithFormat:@"%@/%@", fontPath, name];
            NSLog(@"test13%@", newPath);

            // Check if the font does not exist in the destination directory //
            // 检查目标目录中是否不存在该字体
            if (![manager fileExistsAtPath:newPath]) {
              NSLog(@"test14");
              // Get the path to the font in the main bundle //
              // 获取主包中字体的路径
              NSString *oldPath = [[NSBundle mainBundle] pathForResource:name
                                                                  ofType:nil];

              // Split the old path into components and remove the last
              // component // 分解旧路径为组件并移除最后一个组件
              NSArray *pathArr = [oldPath componentsSeparatedByString:@"/"];
              NSMutableArray *newPathArr =
                  [NSMutableArray arrayWithArray:pathArr];
              [newPathArr removeLastObject];

              // Reconstruct the old path without the last component //
              // 重建不包含最后一个组件的旧路径
              oldPath = [newPathArr componentsJoinedByString:@"/"];
              NSLog(@"test15");
              // Copy font from old path to new path // 从旧路径复制字体到新路径
              [self copyFileFromPath:oldPath toPath:fontPath];
              NSLog(@"test16");
              break;
            }
          }
        }
      }
    }
  }
}

#pragma mark - UISceneSession lifecycle

- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:
        (UISceneSession *)connectingSceneSession
                                   options:(UISceneConnectionOptions *)options {
  // Called when a new scene session is being created.
  // Use this method to select a configuration to create the new scene with.
  return
      [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                     sessionRole:connectingSceneSession.role];
}

- (void)application:(UIApplication *)application
    didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
  // Called when the user discards a scene session.
  // If any sessions were discarded while the application was not running, this
  // will be called shortly after application:didFinishLaunchingWithOptions. Use
  // this method to release any resources that were specific to the discarded
  // scenes, as they will not return.
}

@end
