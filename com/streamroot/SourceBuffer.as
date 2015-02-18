package com.streamroot {
    
    import com.streamroot.Segment;
    import com.streamroot.StreamBufferController;
    import com.streamroot.StreamrootMSE;
    
    import flash.utils.ByteArray;
    
    /**
     * This class represent a buffer of audio or video data
     * In case of hls, both audio and video are muxed in the same segment so we only have one sourceBuffer
     * When segment are appended in NetStream they are deleted from the SourceBuffer
     */
    public class SourceBuffer{
        
        private var _buffer:Array = new Array();
        private var _streamrootMSE:StreamrootMSE;
        private var _appendedEndTime:uint = 0;
        private var _type:String;
        private var _ready:Boolean = false;
        
        
        public function SourceBuffer(streamrootMSE:StreamrootMSE, type:String):void {
            _streamrootMSE = streamrootMSE;
            _type = type;
        }
        
        public function appendSegment(segment:Segment):void {
            _buffer.push(segment);
        }
        
        /**
         * _appendedEndTime is the endTime of the last segment appended in NetStream
         * If no segment has been appended, it is 0
         */
        public function getAppendedEndTime():uint {
            return _appendedEndTime;
        }
        
        /**
         * _ready is true if at least one segment has been appended, false if not
         * It is set a false only at the intialization and after a seek
         */
        public function isReady():Boolean {
            return _ready;
        }
        
        /**
         * Return the next segment to be appended in NetStream
         */
        public function getNextSegmentBytes():ByteArray{
            var bytes:ByteArray = null;
            if(_buffer.length > 0){
                bytes = _buffer[0].getBytes();
                _appendedEndTime = _buffer[0].getEndTime();
                _buffer.splice(0,1);
                _ready = true;
            }
            return bytes;    
        }
        
        /**
         * Remove data between start and end time from the buffer
         * Return bufferEndTime, ie that endTime of the last segment in the buffer, in second
         * (don't be mistaken, it is not the _appendedEndTime which is the endTime of the last segment APPENDED in NetStream)
         */
        public function remove(start:uint, end:uint):uint {
            if(start == 0){
                _buffer = new Array();
            }else{
                while(_buffer.length > 0 && _buffer[_buffer.length-1].getStartTime() >= start*1000){
                    _buffer.pop();
                    
                }
            }
            return getBufferEndTime();
        }
        
        /**
        * Return bufferEndTime, ie that endTime of the last segment in the buffer, in second
        * If buffer is empty, it return the _appendedEndTime, which may be 0 if nothing has been appended in Netstream
        */
        public function getBufferEndTime():uint {
            if(_buffer.length == 0){
                return _appendedEndTime/1000;
            }else{
                return _buffer[_buffer.length-1].getEndTime()/1000;
            }
        }
        /**
         * Clear all data in the buffer
         */
        public function flush():uint{
            _buffer = new Array();
            return getBufferEndTime();
        }
        
        public function getType():String{
            return _type;
        }
        
        public function seek():uint {
            _ready = false;
            return flush();
        }
    }
}