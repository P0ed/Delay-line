#pragma once

struct Buffer {
	float *data;
	int length;
	int offset;
	int loop;

	Buffer(float *data = nullptr, int length = 0, int offset = 0, int loop = 0) {
		this->data = data;
		this->length = length;
		this->offset = offset;
		this->loop = loop ?: length;
	}

	void allocate(int len) {
		data = len ? new float[len] : nullptr;
		length = len;
		offset = 0;
		loop = loop ?: len;
	}
	void deallocate() {
		delete[] data;
		data = nullptr;
		length = 0;
		offset = 0;
		loop = 0;
	}

	float& operator[](int index) {
		return data[(offset + index % loop) % length];
	}

	void read(Buffer buffer) {
		for (int i = 0; i < buffer.loop; ++i) buffer[i] = (*this)[i];
	}
	void write(Buffer buffer) {
		for (int i = 0; i < buffer.loop; ++i) (*this)[i] = buffer[i];
	}

	Buffer sub(int len) { return Buffer(data, length, offset, len); }
};
