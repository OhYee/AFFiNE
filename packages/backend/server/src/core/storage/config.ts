import {
  defineModuleConfig,
  StorageJSONSchema,
  StorageProviderConfig,
} from '../../base';

export interface Storages {
  avatar: {
    storage: ConfigItem<StorageProviderConfig>;
    publicPath: string;
  };
  blob: {
    storage: ConfigItem<StorageProviderConfig>;
    publicPath: string;
  };
}

declare global {
  interface AppConfigSchema {
    storages: Storages;
  }
}

defineModuleConfig('storages', {
  'avatar.publicPath': {
    desc: 'The public accessible path prefix for user avatars.',
    default: '/api/avatars/',
  },
  'avatar.storage': {
    desc: 'The config of storage for user avatars.',
    default: {
      provider: 'fs',
      bucket: 'avatars',
      config: {
        path: '~/.affine/storage',
      },
    },
    schema: StorageJSONSchema,
  },
  'blob.storage': {
    desc: 'The config of storage for all uploaded blobs(images, videos, etc.).',
    default: {
      provider: 'fs',
      bucket: 'blobs',
      config: {
        path: '~/.affine/storage',
      },
    },
    schema: StorageJSONSchema,
  },
  'blob.publicPath': {
    desc: 'The public accessible path prefix for blobs. When set, blob requests will be redirected to this URL prefix directly (e.g., a CDN URL like "https://cdn.example.com/blobs/"). This bypasses the AFFiNE server for serving blob data and reduces server bandwidth usage. Leave empty to serve blobs through the AFFiNE server.',
    default: '',
  },
});
