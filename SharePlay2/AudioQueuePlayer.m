//
//  AudioQueuePlayer.m
//  AudioQueue
//
//  Created by Norihisa Nagano
//

#import "AudioQueuePlayer.h"


@implementation AudioQueuePlayer


@synthesize numPacketsToRead;
@synthesize audioFileID;
@synthesize startingPacketCount;
@synthesize donePlayingFile;

static void outputCallback(void *                  inUserData,
                           AudioQueueRef           inAQ,
                           AudioQueueBufferRef     inBuffer){
    AudioQueuePlayer *player = (__bridge AudioQueuePlayer*)inUserData;
	UInt32 numPackets = player.numPacketsToRead;
    UInt32 numBytes;
    //numPackets分 packetを読み込み
    AudioFileReadPacketData(player.audioFileID,
                            NO,
                            &numBytes,
                            inBuffer -> mPacketDescriptions,
                            player.startingPacketCount,
                            &numPackets,
                            inBuffer -> mAudioData);
		
	if (numPackets > 0) {
        //AudioQueueBufferRefにパケットデータサイズを渡す
        inBuffer->mAudioDataByteSize = numBytes;
        inBuffer->mPacketDescriptionCount = numPackets;
        //inBufferをEnqueueする
		AudioQueueEnqueueBuffer(inAQ,inBuffer, 0, NULL);
        //読み込み位置をインクリメント
        player.startingPacketCount += numPackets;
	}else {//再生するパケットが無ければ終了する        
        if(!player.donePlayingFile){
            NSLog(@"stop");
            AudioQueueStop(inAQ, NO);
            player.donePlayingFile = YES;
        }
	}
}


-(id)init{
    self = [super init];
    if (self != nil) {
        
    }
    return self;
}


-(void)prepareAudioQueue:(NSURL *)url{
    donePlayingFile = NO;
    
    
    //[1]パスからAudioFileIDを取得
    AudioFileOpenURL((__bridge CFURLRef)url,
                     kAudioFileReadPermission,
                     kAudioFileAIFFType, //AIFF
                     &audioFileID);
    
    AudioStreamBasicDescription audioFormat;    
    UInt32 size = sizeof(AudioStreamBasicDescription);
    //[2] kAudioFilePropertyDataFormatをキーにAudioStreamBasicDescriptionを取得
    AudioFileGetProperty (audioFileID,
                          kAudioFilePropertyDataFormat,
                          &size,
                          &audioFormat);
    
    AudioQueueNewOutput(&audioFormat,
                        outputCallback,
                        (__bridge void * _Nullable)(self),
                        NULL,NULL,0,
                        &audioQueueObject);
    
    UInt32 maxPacketSize;
    UInt32 propertySize = sizeof (maxPacketSize);
    AudioFileGetProperty (audioFileID, 
                          kAudioFilePropertyPacketSizeUpperBound,
                          &propertySize,
                          &maxPacketSize);
    
    startingPacketCount = 0;
    AudioQueueBufferRef buffers[3];
    
    //何パケットずつ読み込むか
    numPacketsToRead = 1024;
    UInt32 bufferByteSize = numPacketsToRead * maxPacketSize;
    
    int bufferIndex;
    for (bufferIndex = 0; bufferIndex < 3; bufferIndex++){
        AudioQueueAllocateBuffer(audioQueueObject, 
                                 bufferByteSize,
                                 &buffers[bufferIndex]);
        
        outputCallback ((__bridge void *)(self),audioQueueObject,buffers[bufferIndex]);
    }
}

-(void)play{
    AudioQueueStart(audioQueueObject, NULL);////再生を開始する
}

- (void)dealloc {
    AudioFileClose(audioFileID);               //ファイルのクローズ
    AudioQueueDispose(audioQueueObject, YES);  //キューの破棄
    
}
@end
