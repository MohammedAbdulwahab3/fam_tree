package middleware

import (
	"context"
	"log"
	"os"
	"time"

	"github.com/redis/go-redis/v9"
)

var RedisClient *redis.Client

// InitRedis initializes the Redis client
func InitRedis() *redis.Client {
	redisURL := os.Getenv("REDIS_URL")

	// If no Redis URL is provided, return nil (Redis is optional)
	if redisURL == "" {
		log.Println("REDIS_URL not set, caching disabled")
		return nil
	}

	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Printf("Failed to parse Redis URL: %v", err)
		return nil
	}

	client := redis.NewClient(opt)

	// Test connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err = client.Ping(ctx).Result()
	if err != nil {
		log.Printf("Failed to connect to Redis: %v", err)
		return nil
	}

	log.Println("Successfully connected to Redis")
	RedisClient = client
	return client
}

// GetCache retrieves a value from the cache
func GetCache(ctx context.Context, key string) (string, error) {
	if RedisClient == nil {
		return "", redis.Nil
	}
	return RedisClient.Get(ctx, key).Result()
}

// SetCache stores a value in the cache with an expiration time
func SetCache(ctx context.Context, key string, value string, expiration time.Duration) error {
	if RedisClient == nil {
		return nil
	}
	return RedisClient.Set(ctx, key, value, expiration).Err()
}

// DeleteCache removes a value from the cache
func DeleteCache(ctx context.Context, key string) error {
	if RedisClient == nil {
		return nil
	}
	return RedisClient.Del(ctx, key).Err()
}

// DeleteCachePattern removes all keys matching the pattern
func DeleteCachePattern(ctx context.Context, pattern string) error {
	if RedisClient == nil {
		return nil
	}

	iter := RedisClient.Scan(ctx, 0, pattern, 0).Iterator()
	for iter.Next(ctx) {
		err := RedisClient.Del(ctx, iter.Val()).Err()
		if err != nil {
			return err
		}
	}
	return iter.Err()
}
