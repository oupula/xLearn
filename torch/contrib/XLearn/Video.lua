--------------------------------------------------------------------------------
-- Video: a class to handle videos
-- 
-- Authors: Marco, Clement
--------------------------------------------------------------------------------
do
   local vid = torch.class('Video')
   local vid_format = 'frame-%06d.'

   ----------------------------------------------------------------------
   -- __init()
   -- loads arbitrary videos, using FFMPEG (and a temp cache)
   -- returns a table (list) of images
   --
   function vid:__init(...)
      -- usage
      local args, path, w, h, fps, length, channel, loaded, fmt = toolBox.unpack(
         {...},
         'video.loadVideo',
         'loads a video into a table of tensors:\n'
            .. ' + relies on ffpmeg, which must be installed\n'
            .. ' + creates a local scratch/ to hold jpegs',
         {arg='path', type='string', help='path to video'},
         {arg='width', type='number', help='width', default=500},
         {arg='height', type='number', help='height', default=376},
         {arg='fps', type='number', help='frames per second', default=5},
         {arg='length', type='number', help='length, in seconds', default=5},
         {arg='channel', type='number', help='video channel', default=0},
         {arg='load', type='boolean', help='loads frames after conversion', default=true},
         {arg='encoding', type='string', help='format of dumped frames', default='jpg'}
      )

      -- check ffmpeg existence
      local res = toolBox.exec('ffmpeg')
      if res:find('not found') then 
         local c = toolBox.COLORS
         error(c.Red .. 'ffmpeg required, please install it (apt-get install ffmpeg)' .. c.none)
      end

      -- record meta params
      self.path = path
      self.w = w
      self.h = h
      self.fps = fps
      self.length = length
      self.loaded = loaded
      self.fmt = fmt

      -- load channel(s)
      if type(channel) ~= 'table' then channel = {channel} end
      for i = 1,#channel do
         self[i] = {}
         self:loadChannel(channel[i], self[i])
         self[i].channel = channel
      end

      -- cleanup disk
      if loaded and self.path then
         self:clear()
      end
   end

   -- make name for disk cache from ffmpeg
   function vid:mktemppath(c)
      local sdirname = paths.basename(self.path) .. '_' .. 
      self.fps .. 'fps_' .. 
      self.w .. 'x' .. self.h .. '_' .. 
      self.length .. 's_c' .. 
      c .. '_' .. self.fmt 

      local path_cache = paths.concat('scratch',sdirname)
      return path_cache
   end

   ----------------------------------------------------------------------
   -- loadChannel()
   -- loads a channel
   --
   function vid:loadChannel(channel, where)
      where.path = self:mktemppath(channel)
      -- file name format
      where.sformat = vid_format .. self.fmt
      
      -- Only make cache dir and process video, if dir does not exist
      -- or if the source file is newer than the cache.  Could have
      -- flag to force processing.
      local sfile = paths.concat(where.path,string.format(where.sformat,1))
      if not paths.dirp(where.path)
         or not paths.filep(sfile)
         or toolBox.ftime(self.path) > toolBox.ftime(sfile)
      then
	 -- make disk cache dir
	 os.execute('mkdir -p ' .. where.path) 
	 -- process video
	 if self.path then 
	    local ffmpeg_cmd = 'ffmpeg -i ' .. self.path .. 
	       ' -r ' .. self.fps .. 
	       ' -t ' .. self.length ..
	       ' -map 0.' .. channel ..
	       ' -s ' .. self.w .. 'x' .. self.h .. 
	       ' -qscale 1' ..
	       ' ' .. paths.concat(where.path, where.sformat)
	    print(ffmpeg_cmd)
	    os.execute(ffmpeg_cmd)
	 end
      end

      print('Using frames in ' .. paths.concat(where.path, where.sformat))

      -- load Images
      local idx = 1
      for file in paths.files(where.path) do
         if file ~= '.' and file ~= '..' then
            local fname = paths.concat(where.path,string.format(where.sformat,idx))
            if not self.loaded then
               table.insert(where, fname)
            else
               table.insert(where, image.load(fname))
            end
            idx = idx + 1
         end
      end

      -- update nb of frames
      self.nframes = #where
   end

   
   ----------------------------------------------------------------------
   -- get_frame
   -- as there are two ways to store, you can't index self[1] directly
   function vid:get_frame(c,i)
      if self.loaded then
	 return self[c][i]
      else 
	 if self.fmt == 'png' then 
	    -- png is loaded in RGBA
	    return image.load(self[c][i]):narrow(3,1,3)
	 else
	    return image.load(self[c][i])
	 end
      end
   end


   ----------------------------------------------------------------------
   -- forward
   -- a simple forward() method, that returns the next frame(s) available
   function vid:forward()
      -- current pointer
      self.current = self.current or 1
      -- nb channels
      local nchannels = #self
      if nchannels == 1 then
         -- get next frame
         self.output = self.output or torch.Tensor()
         local nextframe = self:get_frame(1,self.current)
         self.output:resizeAs(nextframe):copy(nextframe)
      else
         -- get next frames
         self.output = self.output or {}
         for c = 1,nchannels do
            local nextframe = self:get_frame(c,self.current)
            self.output[c] = self.output[c] or torch.Tensor()
            self.output[c]:resizeAs(nextframe):copy(nextframe)
         end
      end
      self.current = self.current + 1
      if self.current > #self[1] then self.current = 1 end
      return self.output
   end


   ----------------------------------------------------------------------
   -- save()
   -- save the video with all the channels into AVI format
   --
   function vid:save(...)
      -- usage
      local args, outpath = toolBox.unpack(
         {...},
         'video.saveVideo',
         'save all the frames into a video file:\n'
            .. ' + video must have been loaded with video.loadVideo()\n'
            .. ' + or else, it must be a list of tensors',
         {arg='outpath', type='string', help='path to save the video', default=''}
      )
      -- check outpath
      if outpath == '' then
         local c = toolBox.COLORS
         error(c.Red .. 'You must provide a path to save the video' .. c.none)
      end

      local format = vid_format .. self.fmt
      local nchannels = #self

      -- dump png if content is in ram
      if self.loaded then
         print('Dumping Frames into Disk...')
         local nchannels = #self
         for c = 1,nchannels do
            -- set the channel path if needed
            local fmt = self.fmt
            self.fmt = 'png'
            self[c].path = self:mktemppath(c-1)
            format = vid_format .. 'png'
            self.fmt = fmt
            -- remove if dir exists
            if paths.dirp(self[c].path) then
               os.execute('rm -rf ' .. self[c].path)
            end
            os.execute('mkdir -p ' .. self[c].path)
            for i,frame in ipairs(self[c]) do
               toolBox.dispProgress(i,#self[c])
               local ofname = paths.concat(self[c].path, string.format(format, i))
               image.save(ofname,frame)
            end
         end
      end
      -- warning: -r must come before -i
      local ffmpeg_cmd =  ('ffmpeg -r ' .. self.fps)
      for c = 1,nchannels do
         ffmpeg_cmd = (ffmpeg_cmd ..
                       ' -i ' .. paths.concat(self[c].path, format))
      end
      ffmpeg_cmd = ffmpeg_cmd .. ' -vcodec mjpeg -qscale 1 -an ' .. outpath .. '.avi'
      for c = 2,nchannels do
         ffmpeg_cmd = (ffmpeg_cmd ..
                       '  -vcodec mjpeg -qscale 1 -an  -newvideo')
      end

      -- overwrite the file
      if paths.filep(outpath .. '.avi') then
         print('WARNING: ' .. outpath .. '.avi exist and will be overwritten...')
         os.execute('rm -rf ' .. outpath .. '.avi')
      end
         
      print(ffmpeg_cmd)
      os.execute(ffmpeg_cmd)

      -- cleanup disk
      if self.loaded then
         self:clear()
      end
   end


   ----------------------------------------------------------------------
   -- play()
   -- plays a video
   --
   function vid:play(...)
      -- usage
      local args, zoom, loop, fps, channel = toolBox.unpack(
         {...},
         'video.playVideo',
         'plays a video:\n'
            .. ' + video must have been loaded with video.loadVideo()\n'
            .. ' + or else, it must be a list of tensors',
         {arg='zoom', type='number', help='zoom', default=1},
         {arg='loop', type='boolean', help='loop', default=false},
         {arg='fps', type='number', help='fps [default = given by seq.fps]'},
         {arg='channel', type='number', help='video channel', default=1}
      )

      -- plays vid
      local p =  qtwidget.newwindow(self.w*zoom,self.h*zoom)
      local disp = Displayer()
      local frame = torch.Tensor()
      local pause = 1 / (fps or self.fps) - 0.03
      while true do
         for i,frame in ipairs(self[channel]) do
            if not self.loaded then frame = image.load(frame) end
            disp:show{tensor=frame,painter=p,legend='playing sequence',zoom=zoom}
            if pause and pause>0 then libxlearn.usleep(pause*1e6) end
            collectgarbage()
         end
         if not loop then break end
      end
   end


   ----------------------------------------------------------------------
   -- play3D()
   -- plays a 3D video
   --
   function vid:play3D(...)
      -- usage
      local _, zoom, loop, fps = toolBox.unpack(
         {...},
         'video.playVideo3D',
         'plays a video:\n'
            .. ' + video must have been loaded with video.loadVideo()\n'
            .. ' + or else, it must be a list of pairs of tensors',
         {arg='zoom', type='number', help='zoom', default=1},
         {arg='loop', type='boolean', help='loop', default=false},
         {arg='fps', type='number', help='fps [default = given by seq.fps]'}
      )

      -- plays vid
      local p =  qtwidget.newwindow(self.w*zoom,self.h*zoom)
      local disp = Displayer()
      local framel
      local framer
      local frame = torch.Tensor()
      local pause = 1 / (fps or self.fps) - 0.08
      while true do
         for i = 1,#self[1] do
            -- left/right
            framel = self[1][i]
            framer = self[2][i]
            -- optional load
            if not self.loaded then 
               framel = image.load(framel)
               framer = image.load(framer)
            end
            -- merged
            frame:resize(framel:size(1),framel:size(2),3)
            frame:select(3,1):copy(framel:select(3,1))
            frame:select(3,2):copy(framer:select(3,1))
            frame:select(3,3):copy(framer:select(3,1))
            -- disp
            disp:show{tensor=frame,
                      painter=p,
                      legend='playing 3D sequence [left=RED, right=CYAN]',
                      zoom=zoom}
            if pause and pause>0 then libxlearn.usleep(pause*1e6) end
         end
         if not loop then break end
      end
   end


   ----------------------------------------------------------------------
   -- clear()
   --
   function vid:clear()
      for i = 1,#self do
         local clear = 'rm -rf ' .. self[i].path
         print('clearing video')
         os.execute(clear)
         print(clear)
      end
   end


   ----------------------------------------------------------------------
   -- playYouTube3D() 
   -- plays a video in a format which is acceptable for YouTube 3D (loads jpgs from disk as prepared by Video2imgs)
   --
   function vid:playYouTube3D(...)
      -- usage
      local _, zoom, savefname = toolBox.unpack(
         {...},
         'video.playYouTube3D',
         'plays a video:\n'
            .. ' + video must have been loaded with video.loadVideo()\n'
            .. ' + or else, it must be a list of pairs of tensors',
         {arg='zoom', type='number', help='zoom', default=1},
         {arg='savefname', type='string', help='filename in which output movie will be saved'}
      )

      -- enforce 16:9 ratio
      local h  = self.h
      local w  = (h * 16 / 9)
      local w2 = w/2
      local frame = torch.Tensor(w,h,3)
      print('Frame [' .. frame:size(1) .. ', ' .. frame:size(2) .. ', ' .. frame:size(3) .. ']')

      -- create output
      local outp = Video{width=w, height=h, fps=self.fps, 
                         length=self.length, encoding='png'}

      -- plays vid
      zoom = zoom or 1
      local p =	 qtwidget.newwindow(w*zoom,h*zoom)
      local disp = Displayer()
      local pause = 1 / (self.fps or 5) - 0.08
      local idx = 1
      for i = 1,#self[1] do
         -- left/right
         local frameL = self[1][i]
         local frameR = self[2][i]
         -- optional load
         if not self.loaded then 
            frameL = image.load(frameL)
            frameR = image.load(frameR)
         end
	 print('FrameL [' .. frameL:size(1) .. ', ' .. frameL:size(2) .. ', ' .. frameL:size(3) .. ']')
	 
         -- left
         if not (frameL:size(1) == w2 and frameL:size(2) == h) then
            image.scale(frameL,frame:narrow(1,1,w2),'bilinear')
         else
            frame:narrow(1,1,w2):copy(frameL)
         end
         -- right
         if not (frameR:size(1) == w2 and frameR:size(2) == h) then
            image.scale(frameR,frame:narrow(1,w2,w2),'bilinear')
         else 
            frame:narrow(1,w2,w2):copy(frameR)
         end
         frameL = nil 
         frameR = nil
         collectgarbage() -- force GC ...
         -- disp
         disp:show{tensor=frame,painter=p,legend='playing 3D sequence',zoom=zoom}
         if savefname then
            local ofname = paths.concat(outp[1].path, string.format(outp[1].sformat, idx))
            table.insert(outp[1], ofname)
            image.save(ofname,frame)
         end
         idx = idx + 1
         -- need pause to take the image loading time into account.
         if pause and pause>0 then libxlearn.usleep(pause*1e6) end
      end

      -- convert pngs to AVI
      if savefname then
         outp:save(savefname)
      end
   end
end
