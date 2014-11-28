/*
**The role of this class is to wrap mangui's transcoding stack and implement the callbacks that handle the tag and fragmentData info
*/

package com.hls
{

    import flash.utils.ByteArray;
    import flash.utils.IDataInput;

    import com.streamroot.TranscodeWorker;
    import com.hlsmangui.TSDemuxer;

    //[Event(name="notifySegmentDuration", type="org.osmf.events.HTTPStreamingFileHandlerEvent")]
    //[Event(name="notifyTimeBias", type="org.osmf.events.HTTPStreamingFileHandlerEvent")]


    public class HlsTranscodehandler
    {
        private var _transcodeWorker:TranscodeWorker;
        private var _demux:TSDemuxer;

        
        public function HlsTranscodehandler(transcodeWorker:TranscodeWorker)
        {   
            _transcodeWorker = transcodeWorker;
            _demux = new TSDemuxer();
        }

        /*
        **This method replaces processFileSegment_bigger in old stack. Here we provide the full segment because spltting by packets
        /**to avoid blocking is already managed by parseTimer in TSDemuxer
        */
        public function toTranscoding(input:IDataInput):ByteArray
        {
            var output:ByteArray;

            output = new ByteArray();
            _demux.append(input);
            //TODO: ici récupérer le segment FLV (ou direct dans le bon callback)

        }

        /** triggered by demux, it should return the audio track to be parsed */
        private function _fragParsingAudioSelectionHandler(audioTrackList : Vector.<AudioTrack>) : AudioTrack {
            return _audioTrackController.audioTrackSelectionHandler(audioTrackList);
        }

        /** triggered by demux, it should return video width/height */
        private function _fragParsingVideoMetadataHandler(width : uint, height : uint) : void {
            var fragData : FragmentData = _frag_current.data;
            if (fragData.video_width == 0) {
                CONFIG::LOGGING {
                    Log.debug("AVC: width/height:" + width + "/" + height);
                }
                fragData.video_width = width;
                fragData.video_height = height;
            }
        }

        /** triggered when demux has retrieved some tags from fragment **/
        private function _fragParsingProgressHandler(tags : Vector.<FLVTag>) : void {
            CONFIG::LOGGING {
                Log.debug2(tags.length + " tags extracted");
            }
            var tag : FLVTag;
            /* ref PTS / DTS value for PTS looping */
            var fragData : FragmentData = _frag_current.data;
            var ref_pts : Number = fragData.pts_start_computed;
            // Audio PTS/DTS normalization + min/max computation
            for each (tag in tags) {
                tag.pts = PTS.normalize(ref_pts, tag.pts);
                tag.dts = PTS.normalize(ref_pts, tag.dts);
                switch( tag.type ) {
                    case FLVTag.AAC_HEADER:
                    case FLVTag.AAC_RAW:
                    case FLVTag.MP3_RAW:
                        fragData.audio_found = true;
                        fragData.tags_audio_found = true;
                        fragData.tags_pts_min_audio = Math.min(fragData.tags_pts_min_audio, tag.pts);
                        fragData.tags_pts_max_audio = Math.max(fragData.tags_pts_max_audio, tag.pts);
                        fragData.pts_min_audio = Math.min(fragData.pts_min_audio, tag.pts);
                        fragData.pts_max_audio = Math.max(fragData.pts_max_audio, tag.pts);
                        break;
                    case FLVTag.AVC_HEADER:
                    case FLVTag.AVC_NALU:
                    case FLVTag.DISCONTINUITY:
                        fragData.video_found = true;
                        fragData.tags_video_found = true;
                        fragData.tags_pts_min_video = Math.min(fragData.tags_pts_min_video, tag.pts);
                        fragData.tags_pts_max_video = Math.max(fragData.tags_pts_max_video, tag.pts);
                        fragData.pts_min_video = Math.min(fragData.pts_min_video, tag.pts);
                        fragData.pts_max_video = Math.max(fragData.pts_max_video, tag.pts);
                        break;
                    case FLVTag.METADATA:
                    default:
                        break;
                }
                fragData.tags.push(tag);
            }

            /* try to do progressive buffering here. 
             * only do it in case :
             * 		first fragment is already loaded 
             *      if first fragment is not loaded, we can do it if startlevel is already defined (if startFromLevel is set to -1
             *      we first need to download one fragment to check the dl bw, in order to assess start level ...)
             *      in case startFromLevel is to -1 and there is only one level, then we can do progressive buffering
             */
            if (( _fragment_first_loaded || (_manifest_just_loaded && (HLSSettings.startFromLevel !== -1 || HLSSettings.startFromBitrate !== -1 || _levels.length == 1) ) )) {
                if (_demux.audio_expected() && !fragData.audio_found) {
                    /* if no audio tags found, it means that only video tags have been retrieved here
                     * we cannot do progressive buffering in that case.
                     * we need to have some new audio tags to inject as well
                     */
                    return;
                }

                if (fragData.tag_pts_min != Number.POSITIVE_INFINITY && fragData.tag_pts_max != Number.NEGATIVE_INFINITY) {
                    var min_offset : Number = _frag_current.start_time + fragData.tag_pts_start_offset / 1000;
                    var max_offset : Number = _frag_current.start_time + fragData.tag_pts_end_offset / 1000;
                    // in case of cold start/seek use case,
                    if (!_fragment_first_loaded ) {
                        /* ensure buffer max offset is greater than requested seek position. 
                         * this will avoid issues with accurate seeking feature */
                        if (_seek_pos > max_offset) {
                            // cannot do progressive buffering until we have enough data to reach requested seek offset
                            return;
                        }
                    }

                    //TODO: A PRIORI CA CE SERA PLUTOT DANS LA PARTIE JS AVEC LE MAP GENERATOR
                    if (_pts_analyzing == true) {
                        _pts_analyzing = false;
                        _levels[_level].updateFragment(_frag_current.seqnum, true, fragData.pts_min, fragData.pts_min + _frag_current.duration * 1000);
                        /* in case we are probing PTS, retrieve PTS info and synchronize playlist PTS / sequence number */
                        CONFIG::LOGGING {
                            Log.debug("analyzed  PTS " + _frag_current.seqnum + " of [" + (_levels[_level].start_seqnum) + "," + (_levels[_level].end_seqnum) + "],level " + _level + " m PTS:" + fragData.pts_min);
                        }
                        /* check if fragment loaded for PTS analysis is the next one
                        if this is the expected one, then continue
                        if not, then cancel current fragment loading, next call to loadnextfragment() will load the right seqnum
                         */
                        var next_seqnum : Number = _levels[_level].getSeqNumNearestPTS(_frag_previous.data.pts_start, _frag_current.continuity) + 1;
                        CONFIG::LOGGING {
                            Log.debug("analyzed PTS : getSeqNumNearestPTS(level,pts,cc:" + _level + "," + _frag_previous.data.pts_start + "," + _frag_current.continuity + ")=" + next_seqnum);
                        }
                        // CONFIG::LOGGING {
                        // Log.info("seq/next:"+ _seqnum+"/"+ next_seqnum);
                        // }
                        if (next_seqnum != _frag_current.seqnum) {
                            _pts_just_analyzed = true;
                            CONFIG::LOGGING {
                                Log.debug("PTS analysis done on " + _frag_current.seqnum + ", matching seqnum is " + next_seqnum + " of [" + (_levels[_level].start_seqnum) + "," + (_levels[_level].end_seqnum) + "],cancel loading and get new one");
                            }
                            // cancel loading
                            _stop_load();
                            // clean-up tags
                            fragData.tags = new Vector.<FLVTag>();
                            fragData.tags_audio_found = fragData.tags_video_found = false;
                            // tell that new fragment could be loaded
                            _loading_state = LOADING_IDLE;
                            return;
                        }
                    }
                    //TODO: A VOIR CE QU'ON FAIT ET SI ON CHANGE NOTRE NETSTREAM POUR FAIRE UN TRUC PLUS PROPORE A LA MANGUI
                    // provide tags to HLSNetStream
                    _tags_callback(_level, _frag_current.continuity, _frag_current.seqnum, !fragData.video_found, fragData.video_width, fragData.video_height, _frag_current.tag_list, fragData.tags, fragData.tag_pts_min, fragData.tag_pts_max, _hasDiscontinuity, min_offset, _frag_current.program_date + fragData.tag_pts_start_offset);
                    var processing_duration : Number = (new Date().valueOf() - _frag_current.metrics.loading_request_time);
                    var bandwidth : Number = Math.round(fragData.bytesLoaded * 8000 / processing_duration);
                    var tagsMetrics : HLSLoadMetrics = new HLSLoadMetrics(_level, bandwidth, fragData.tag_pts_end_offset, processing_duration);
                    _hls.dispatchEvent(new HLSEvent(HLSEvent.TAGS_LOADED, tagsMetrics));
                    _hasDiscontinuity = false;
                    fragData.tags = new Vector.<FLVTag>();
                    if (fragData.tags_audio_found) {
                        fragData.tags_pts_min_audio = fragData.tags_pts_max_audio;
                        fragData.tags_audio_found = false;
                    }
                    if (fragData.tags_video_found) {
                        fragData.tags_pts_min_video = fragData.tags_pts_max_video;
                        fragData.tags_video_found = false;
                    }
                }
            }
        }

        /** triggered when demux has completed fragment parsing **/
        private function _fragParsingCompleteHandler() : void {
            if (_loading_state == LOADING_IDLE)
                return;
            var hlsError : HLSError;
            var fragData : FragmentData = _frag_current.data;
            if (!fragData.audio_found && !fragData.video_found) {
                hlsError = new HLSError(HLSError.FRAGMENT_PARSING_ERROR, _frag_current.url, "error parsing fragment, no tag found");
                _hls.dispatchEvent(new HLSEvent(HLSEvent.ERROR, hlsError));
            }
            if (fragData.audio_found) {
                null;
                // just to stop the compiler warning
                CONFIG::LOGGING {
                    Log.debug("m/M audio PTS:" + fragData.pts_min_audio + "/" + fragData.pts_max_audio);
                }
            }

            if (fragData.video_found) {
                CONFIG::LOGGING {
                    Log.debug("m/M video PTS:" + fragData.pts_min_video + "/" + fragData.pts_max_video);
                }
                if (!fragData.audio_found) {
                } else {
                    null;
                    // just to avoid compilation warnings if CONFIG::LOGGING is false
                    CONFIG::LOGGING {
                        Log.debug("Delta audio/video m/M PTS:" + (fragData.pts_min_video - fragData.pts_min_audio) + "/" + (fragData.pts_max_video - fragData.pts_max_audio));
                    }
                }
            }

            // Calculate bandwidth
            var fragMetrics : FragmentMetrics = _frag_current.metrics;
            fragMetrics.parsing_end_time = new Date().valueOf();
            CONFIG::LOGGING {
                Log.debug("Total Process duration/length/bw:" + fragMetrics.processing_duration + "/" + fragMetrics.size + "/" + (fragMetrics.bandwidth / 1024).toFixed(0) + " kb/s");
            }

            if (_manifest_just_loaded) {
                _manifest_just_loaded = false;
                if (HLSSettings.startFromLevel === -1 && HLSSettings.startFromBitrate === -1 && _levels.length > 1) {
                    // check if we can directly switch to a better bitrate, in case download bandwidth is enough
                    var bestlevel : int = _autoLevelManager.getbestlevel(fragMetrics.bandwidth);
                    if (bestlevel > _level) {
                        CONFIG::LOGGING {
                            Log.info("enough download bandwidth, adjust start level from " + _level + " to " + bestlevel);
                        }
                        // let's directly jump to the accurate level to improve quality at player start
                        _level = bestlevel;
                        _loading_state = LOADING_IDLE;
                        _switchlevel = true;
                        _hls.dispatchEvent(new HLSEvent(HLSEvent.LEVEL_SWITCH, _level));
                        return;
                    }
                }
            }

            try {
                _switchlevel = false;
                CONFIG::LOGGING {
                    Log.debug("Loaded        " + _frag_current.seqnum + " of [" + (_levels[_level].start_seqnum) + "," + (_levels[_level].end_seqnum) + "],level " + _level + " m/M PTS:" + fragData.pts_min + "/" + fragData.pts_max);
                }
                var start_offset : Number = _levels[_level].updateFragment(_frag_current.seqnum, true, fragData.pts_min, fragData.pts_max);
                // set pts_start here, it might not be updated directly in updateFragment() if this loaded fragment has been removed from a live playlist
                fragData.pts_start = fragData.pts_min;
                _hls.dispatchEvent(new HLSEvent(HLSEvent.PLAYLIST_DURATION_UPDATED, _levels[_level].duration));
                _loading_state = LOADING_IDLE;

                var tagsMetrics : HLSLoadMetrics = new HLSLoadMetrics(_level, fragMetrics.bandwidth, fragData.pts_max - fragData.pts_min, fragMetrics.processing_duration);

                if (fragData.tags.length) {
                    _tags_callback(_level, _frag_current.continuity, _frag_current.seqnum, !fragData.video_found, fragData.video_width, fragData.video_height, _frag_current.tag_list, fragData.tags, fragData.tag_pts_min, fragData.tag_pts_max, _hasDiscontinuity, start_offset + fragData.tag_pts_start_offset / 1000, _frag_current.program_date + fragData.tag_pts_start_offset);
                    _hls.dispatchEvent(new HLSEvent(HLSEvent.TAGS_LOADED, tagsMetrics));
                    if (fragData.tags_audio_found) {
                        fragData.tags_pts_min_audio = fragData.tags_pts_max_audio;
                        fragData.tags_audio_found = false;
                    }
                    if (fragData.tags_video_found) {
                        fragData.tags_pts_min_video = fragData.tags_pts_max_video;
                        fragData.tags_video_found = false;
                    }
                    _hasDiscontinuity = false;
                    fragData.tags = new Vector.<FLVTag>();
                }
                _pts_analyzing = false;
                _hls.dispatchEvent(new HLSEvent(HLSEvent.FRAGMENT_LOADED, tagsMetrics));
                _fragment_first_loaded = true;
                _frag_previous = _frag_current;
            } catch (error : Error) {
                hlsError = new HLSError(HLSError.OTHER_ERROR, _frag_current.url, error.message);
                _hls.dispatchEvent(new HLSEvent(HLSEvent.ERROR, hlsError));
            }
        }

        /** return current quality level. **/
        public function get level() : int {
            return _level;
        };

        /* set current quality level */
        public function set level(level : int) : void {
            _manual_level = level;
        };

        /** get auto/manual level mode **/
        public function get autolevel() : Boolean {
            if (_manual_level == -1) {
                return true;
            } else {
                return false;
            }
        };
    }
}