const loadJimp = async () => {
  const response = await fetch('https://cdn.jsdelivr.net/npm/jimp@0.16.2-canary.919.1052.0/browser/lib/jimp.js');
  const scriptText = await response.text();
  eval(scriptText);
};

self.onmessage = async function(event) {
  try {
    const data = event.data;

    if (!data.imageUrl) {
      throw new Error('Missing image URL in worker data');
    }

    if (typeof Jimp === 'undefined') {
      await loadJimp();
    }

    // Fetch the image
    const response = await fetch(data.imageUrl);
    const buffer = await response.arrayBuffer();

    // Load the image into Jimp
    const image = await Jimp.read(Buffer.from(buffer));

    // Calculate scaling factors
    const scaleX = image.bitmap.width / data.previewWidth;
    const scaleY = image.bitmap.height / data.previewHeight;

    // Calculate crop dimensions
    const scaledLeft = Math.floor(data.left * scaleX);
    const scaledTop = Math.floor(data.top * scaleY);
    const scaledWidth = Math.floor(data.width * scaleX);
    const scaledHeight = Math.floor(data.height * scaleY);

    // Crop the image
    const croppedImage = image.crop(
      Math.max(0, scaledLeft),
      Math.max(0, scaledTop),
      Math.min(scaledWidth, image.bitmap.width - scaledLeft),
      Math.min(scaledHeight, image.bitmap.height - scaledTop)
    );

    // Convert to PNG buffer
    const bufferTwo = await croppedImage.getBufferAsync(Jimp.MIME_PNG);

    // Convert to regular integers that Dart can handle
    const uint8Array = new Uint8Array(bufferTwo);
    const intArray = Array.from(uint8Array).map(Number);

    // Send the processed image back
    self.postMessage({
      processedImage: intArray
    });

  } catch (error) {
    self.postMessage({ error: error.toString() });
  }
};